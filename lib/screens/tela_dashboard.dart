import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_theme.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/domain/app_user.dart';
import '../features/company/data/company_repository.dart';
import '../features/dashboard/application/dashboard_analytics.dart';
import '../features/inventory/data/product_repository.dart';
import '../features/inventory/data/stock_movement_repository.dart';
import '../features/inventory/domain/product.dart';
import '../features/inventory/domain/stock_movement.dart';
import '../shared/widgets/page_container.dart';

final dashboardProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  companyId,
) {
  return ref.watch(productRepositoryProvider).watchProducts(companyId);
});

final dashboardMovementsProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, companyId) {
      return ref
          .watch(stockMovementRepositoryProvider)
          .watchRecentMovements(companyId);
    });

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  static const routePath = '/dashboard';
  static const routeName = 'dashboard';

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DashboardPeriod _period = DashboardPeriod.last30Days;
  String? _localCompanyId;
  String? _companyError;
  bool _preparingCompany = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const _DashboardMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar sua conta',
        description: 'Atualize a página e tente novamente.',
      ),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final companyId = _localCompanyId ?? user.activeCompanyId;
        if (companyId == null && !_preparingCompany && _companyError == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ensureCompany(user);
          });
        }

        return _buildPage(companyId);
      },
    );
  }

  Widget _buildPage(String? companyId) {
    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Dashboard',
            subtitle: 'Vendas, faturamento e rentabilidade do negócio',
            trailing: _PeriodSelector(
              value: _period,
              onChanged: (value) => setState(() => _period = value),
            ),
          ),
          const SizedBox(height: 20),
          if (_companyError != null)
            _DashboardMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível preparar sua empresa',
              description: _companyError!,
              actionLabel: 'Tentar novamente',
              onAction: () {
                final user = ref.read(authStateProvider).asData?.value;
                if (user == null) return;
                setState(() => _companyError = null);
                _ensureCompany(user);
              },
            )
          else if (companyId == null || _preparingCompany)
            const _DashboardLoading()
          else
            _buildData(companyId),
        ],
      ),
    );
  }

  Widget _buildData(String companyId) {
    final productsState = ref.watch(dashboardProductsProvider(companyId));
    final movementsState = ref.watch(dashboardMovementsProvider(companyId));

    return productsState.when(
      loading: () => const _DashboardLoading(),
      error: (error, stackTrace) => const _DashboardMessage(
        icon: Icons.inventory_2_outlined,
        title: 'Não foi possível carregar os produtos',
        description: 'Confira sua conexão e tente novamente.',
      ),
      data: (products) => movementsState.when(
        loading: () => const _DashboardLoading(),
        error: (error, stackTrace) => const _DashboardMessage(
          icon: Icons.query_stats_outlined,
          title: 'Não foi possível carregar as vendas',
          description: 'Confira sua conexão e tente novamente.',
        ),
        data: (movements) {
          final analytics = DashboardAnalytics.calculate(
            products: products,
            movements: movements,
            period: _period,
          );
          return _DashboardContent(analytics: analytics);
        },
      ),
    );
  }

  Future<void> _ensureCompany(AppUser user) async {
    final existingCompanyId = _localCompanyId ?? user.activeCompanyId;
    if (existingCompanyId != null && existingCompanyId.isNotEmpty) return;

    setState(() {
      _preparingCompany = true;
      _companyError = null;
    });

    try {
      final companyId = await ref
          .read(companyRepositoryProvider)
          .ensureDefaultCompany(user.id);
      if (mounted) setState(() => _localCompanyId = companyId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _companyError = 'Não foi possível acessar os dados da empresa.';
        });
      }
    } finally {
      if (mounted) setState(() => _preparingCompany = false);
    }
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.analytics});

  final DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final percent = NumberFormat.percentPattern('pt_BR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EstimateNotice(),
        const SizedBox(height: 16),
        _MetricGrid(
          metrics: [
            _DashboardMetric(
              label: 'Faturamento estimado',
              value: currency.format(analytics.revenue),
              detail: '${analytics.saleCount} operações de venda',
              icon: Icons.payments_outlined,
              color: AppTheme.primaryBlue,
            ),
            _DashboardMetric(
              label: 'Lucro bruto estimado',
              value: currency.format(analytics.profit),
              detail: 'Margem de ${percent.format(analytics.margin)}',
              icon: Icons.trending_up,
              color: AppTheme.success,
            ),
            _DashboardMetric(
              label: 'Itens vendidos',
              value: NumberFormat.decimalPattern(
                'pt_BR',
              ).format(analytics.unitsSold),
              detail: 'unidades no período',
              icon: Icons.shopping_bag_outlined,
              color: AppTheme.aqua,
            ),
            _DashboardMetric(
              label: 'Ticket médio estimado',
              value: currency.format(analytics.averageTicket),
              detail: 'por operação de venda',
              icon: Icons.receipt_long_outlined,
              color: AppTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final chart = _RevenueChart(
              analytics: analytics,
              currency: currency,
            );
            final closing = _ClosingSummary(
              analytics: analytics,
              currency: currency,
              percent: percent,
            );

            if (constraints.maxWidth < 900) {
              return Column(
                children: [chart, const SizedBox(height: 16), closing],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: chart),
                const SizedBox(width: 16),
                Expanded(child: closing),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bestSelling = _RankingCard(
              title: 'Produtos mais vendidos',
              subtitle: 'Quantidade vendida no período',
              icon: Icons.workspace_premium_outlined,
              color: AppTheme.primaryBlue,
              items: analytics.bestSellingProducts.take(5).map((product) {
                final unitLabel = product.unitsSold == 1
                    ? 'unidade'
                    : 'unidades';
                return _RankingItem(
                  name: product.productName,
                  value: product.unitsSold.toDouble(),
                  valueLabel: '${product.unitsSold} $unitLabel',
                );
              }).toList(),
            );
            final mostProfitable = _RankingCard(
              title: 'Maior lucro estimado',
              subtitle: 'Lucro bruto por produto',
              icon: Icons.stacked_line_chart,
              color: AppTheme.success,
              items: analytics.mostProfitableProducts.take(5).map((product) {
                return _RankingItem(
                  name: product.productName,
                  value: product.profit,
                  valueLabel: currency.format(product.profit),
                );
              }).toList(),
            );

            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  bestSelling,
                  const SizedBox(height: 16),
                  mostProfitable,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: bestSelling),
                const SizedBox(width: 16),
                Expanded(child: mostProfitable),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _StockPosition(analytics: analytics, currency: currency),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final DashboardPeriod value;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 210,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DashboardPeriod>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more),
          items: [
            for (final period in DashboardPeriod.values)
              DropdownMenuItem(value: period, child: Text(period.label)),
          ],
          onChanged: (period) {
            if (period != null) onChanged(period);
          },
        ),
      ),
    );
  }
}

class _EstimateNotice extends StatelessWidget {
  const _EstimateNotice();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
        border: Border(
          left: BorderSide(color: colorScheme.secondary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Os valores financeiros usam os preços e custos atuais dos produtos.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 580
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 148,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: metric.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(metric.icon, color: metric.color, size: 21),
                    ),
                    const Spacer(),
                    Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      metric.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.analytics, required this.currency});

  final DashboardAnalytics analytics;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final points = analytics.series;
    final maximum = points.fold<double>(
      0,
      (value, point) => point.revenue > value ? point.revenue : value,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faturamento no período',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        currency.format(analytics.revenue),
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (maximum <= 0)
              const SizedBox(
                height: 220,
                child: _EmptyAnalysis(
                  icon: Icons.bar_chart_outlined,
                  title: 'Ainda não há vendas neste período',
                  description:
                      'As vendas registradas em Movimentações aparecerão neste gráfico.',
                ),
              )
            else
              SizedBox(
                height: 220,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _compactCurrency(maximum),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _compactCurrency(maximum / 2),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'R\$ 0',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final point in points)
                            Expanded(
                              child: _RevenueBar(
                                point: point,
                                maximum: maximum,
                                currency: currency,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RevenueBar extends StatelessWidget {
  const _RevenueBar({
    required this.point,
    required this.maximum,
    required this.currency,
  });

  final DashboardSeriesPoint point;
  final double maximum;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = maximum == 0 ? 0.0 : point.revenue / maximum;
    final isSingleDay = point.start == point.end;
    final dateLabel = DateFormat('dd/MM').format(point.start);
    final periodLabel = isSingleDay
        ? DateFormat('dd/MM/yyyy').format(point.start)
        : '${DateFormat('dd/MM').format(point.start)} a ${DateFormat('dd/MM/yyyy').format(point.end)}';

    return Tooltip(
      message:
          '$periodLabel\nFaturamento: ${currency.format(point.revenue)}\nLucro: ${currency.format(point.profit)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: ratio == 0 ? 0.015 : ratio.clamp(0.015, 1),
                  widthFactor: 0.72,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: point.revenue == 0
                          ? colorScheme.surfaceContainerHighest
                          : AppTheme.primaryBlue,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 17,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingSummary extends StatelessWidget {
  const _ClosingSummary({
    required this.analytics,
    required this.currency,
    required this.percent,
  });

  final DashboardAnalytics analytics;
  final NumberFormat currency;
  final NumberFormat percent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.summarize_outlined,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fechamento do período',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SummaryRow(
              label: 'Faturamento',
              value: currency.format(analytics.revenue),
            ),
            _SummaryRow(
              label: 'Custo dos produtos',
              value: currency.format(analytics.cost),
            ),
            const Divider(height: 25),
            _SummaryRow(
              label: 'Lucro bruto',
              value: currency.format(analytics.profit),
              emphasized: true,
            ),
            _SummaryRow(
              label: 'Margem bruta',
              value: percent.format(analytics.margin),
            ),
            _SummaryRow(
              label: 'Operações de venda',
              value: '${analytics.saleCount}',
            ),
            _SummaryRow(
              label: 'Itens vendidos',
              value: '${analytics.unitsSold}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: style, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _RankingItem {
  const _RankingItem({
    required this.name,
    required this.value,
    required this.valueLabel,
  });

  final String name;
  final double value;
  final String valueLabel;
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_RankingItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maximum = items.fold<double>(
      0,
      (value, item) => item.value > value ? item.value : value,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const SizedBox(
                height: 180,
                child: _EmptyAnalysis(
                  icon: Icons.insights_outlined,
                  title: 'Sem dados para o ranking',
                  description: 'Registre vendas para acompanhar o desempenho.',
                ),
              )
            else
              for (var index = 0; index < items.length; index++) ...[
                _RankingRow(
                  position: index + 1,
                  item: items[index],
                  progress: maximum <= 0 ? 0 : items[index].value / maximum,
                  color: color,
                ),
                if (index != items.length - 1) const SizedBox(height: 15),
              ],
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.position,
    required this.item,
    required this.progress,
    required this.color,
  });

  final int position;
  final _RankingItem item;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$positionº',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(item.valueLabel),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockPosition extends StatelessWidget {
  const _StockPosition({required this.analytics, required this.currency});

  final DashboardAnalytics analytics;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final potentialProfit =
        analytics.potentialSaleValue - analytics.stockCostValue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppTheme.aqua),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Posição financeira do estoque',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final items = [
                  _StockValue(
                    label: 'Capital em estoque',
                    value: currency.format(analytics.stockCostValue),
                  ),
                  _StockValue(
                    label: 'Venda potencial',
                    value: currency.format(analytics.potentialSaleValue),
                  ),
                  _StockValue(
                    label: 'Lucro potencial',
                    value: currency.format(potentialProfit),
                  ),
                ];

                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        items[index],
                        if (index != items.length - 1)
                          const Divider(height: 25),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      Expanded(child: items[index]),
                      if (index != items.length - 1)
                        const SizedBox(
                          height: 42,
                          child: VerticalDivider(width: 28),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StockValue extends StatelessWidget {
  const _StockValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _EmptyAnalysis extends StatelessWidget {
  const _EmptyAnalysis({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 320,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 46, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

String _compactCurrency(double value) {
  if (value >= 1000000) {
    return 'R\$ ${(value / 1000000).toStringAsFixed(1)} mi';
  }
  if (value >= 1000) return 'R\$ ${(value / 1000).toStringAsFixed(1)} mil';
  return 'R\$ ${value.toStringAsFixed(0)}';
}
