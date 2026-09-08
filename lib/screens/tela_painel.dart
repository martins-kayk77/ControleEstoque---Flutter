import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/bootstrap/firebase_bootstrap.dart';
import '../app/theme/app_theme.dart';
import '../shared/widgets/page_container.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static const routePath = '/';
  static const routeName = 'dashboard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebase = ref.watch(firebaseBootstrapProvider);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Dashboard',
            subtitle: 'Controle e leitura rápida do estoque',
            trailing: _FirebaseStatusChip(firebase),
          ),
          const SizedBox(height: 20),
          const _DashboardBanner(),
          const SizedBox(height: 20),
          const _QuickActions(),
          const SizedBox(height: 20),
          _MetricGrid(
            metrics: [
              DashboardMetric(
                label: 'Produtos',
                value: '0',
                detail: 'cadastrados',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.primaryBlue,
              ),
              DashboardMetric(
                label: 'Valor em custo',
                value: currency.format(0),
                detail: 'em estoque',
                icon: Icons.payments_outlined,
                color: AppTheme.success,
              ),
              DashboardMetric(
                label: 'Estoque baixo',
                value: '0',
                detail: 'precisam atenção',
                icon: Icons.warning_amber_outlined,
                color: AppTheme.warning,
              ),
              DashboardMetric(
                label: 'Movimentações',
                value: '0',
                detail: 'no histórico',
                icon: Icons.sync_alt_outlined,
                color: AppTheme.aqua,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _DashboardPanels(),
        ],
      ),
    );
  }
}

class DashboardMetric {
  const DashboardMetric({
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

class _DashboardBanner extends StatelessWidget {
  const _DashboardBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.deepBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;

            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prumo',
                  style: textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Base pronta para produtos, entradas, saídas, contagens e precificação.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            );

            final status = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _BannerPill(icon: Icons.lock_outline, label: 'Multiempresa'),
                _BannerPill(icon: Icons.history, label: 'Histórico'),
                _BannerPill(icon: Icons.calculate_outlined, label: 'Preços'),
              ],
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [summary, const SizedBox(height: 16), status],
              );
            }

            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 20),
                status,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BannerPill extends StatelessWidget {
  const _BannerPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 640
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
            mainAxisExtent: 152,
          ),
          itemBuilder: (context, index) {
            return _MetricCard(metric: metrics[index]);
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(metric.icon, color: metric.color, size: 22),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: metric.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineSmall,
            ),
            Text(
              metric.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/products'),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Produtos'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/stock'),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Entrada'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/stock'),
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('Saída'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/counts'),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Contagem'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/pricing'),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Precificar'),
        ),
      ],
    );
  }
}

class _DashboardPanels extends StatelessWidget {
  const _DashboardPanels();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        final panels = const [
          _DashboardPanel(
            title: 'Alertas de estoque',
            icon: Icons.notifications_none,
            line: 'Produtos sem estoque e abaixo do mínimo aparecerão aqui.',
          ),
          _DashboardPanel(
            title: 'Reposição',
            icon: Icons.shopping_cart_outlined,
            line:
                'A lista de compras será calculada a partir do estoque atual.',
          ),
          _DashboardPanel(
            title: 'Giro de produtos',
            icon: Icons.trending_up,
            line: 'Velocidade de saída e produtos parados entram nesta área.',
          ),
          _DashboardPanel(
            title: 'Canais de venda',
            icon: Icons.hub_outlined,
            line:
                'Comparação de margem por WhatsApp, Instagram e marketplaces.',
          ),
        ];

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 3.5 : 3,
          children: panels,
        );
      },
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.icon,
    required this.line,
  });

  final String title;
  final IconData icon;
  final String line;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
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

class _FirebaseStatusChip extends StatelessWidget {
  const _FirebaseStatusChip(this.result);

  final FirebaseBootstrapResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReady = result.isReady;

    return Chip(
      avatar: Icon(
        isReady ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        size: 18,
        color: isReady ? AppTheme.success : AppTheme.warning,
      ),
      label: Text(result.message),
      backgroundColor: isReady
          ? colorScheme.secondaryContainer
          : colorScheme.tertiaryContainer,
      side: BorderSide.none,
    );
  }
}
