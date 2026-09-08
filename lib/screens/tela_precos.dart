import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_theme.dart';
import '../features/pricing/application/pricing_calculator.dart';
import '../features/pricing/domain/pricing_models.dart';
import '../shared/widgets/page_container.dart';

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  static const routePath = '/pricing';
  static const routeName = 'pricing';

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final percent = NumberFormat.percentPattern('pt_BR');
    final platform = PricingPlatform(
      id: 'example',
      companyId: 'example',
      name: 'Canal padrão',
      fees: const [
        PricingFee(
          id: 'commission',
          name: 'Comissão',
          type: PricingFeeType.percentage,
          value: 0.10,
        ),
      ],
    );
    final result = PricingCalculator.priceForTargetProfit(
      PriceForProfitInput(
        productCost: 40,
        additionalCosts: 3,
        desiredProfit: 20,
        platform: platform,
      ),
    );

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Preços',
            subtitle: 'Calculadora preparada para canais e taxas',
            trailing: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Novo cálculo'),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              final resultPanel = _PriceResultPanel(
                result: result,
                currency: currency,
                percent: percent,
              );
              final summary = _PricingSummary(
                platform: platform,
                result: result,
                currency: currency,
              );

              if (!isWide) {
                return Column(
                  children: [resultPanel, const SizedBox(height: 12), summary],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: resultPanel),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: summary),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const _PricingShellGrid(),
        ],
      ),
    );
  }
}

class _PriceResultPanel extends StatelessWidget {
  const _PriceResultPanel({
    required this.result,
    required this.currency,
    required this.percent,
  });

  final PricingResult result;
  final NumberFormat currency;
  final NumberFormat percent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.deepBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sell_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Modo 1: quero saber o preço',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              currency.format(result.salePrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Preço recomendado para atingir o lucro desejado.',
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ResultPill(
                  label: 'Lucro',
                  value: currency.format(result.profit),
                ),
                _ResultPill(
                  label: 'Margem',
                  value: percent.format(result.margin),
                ),
                _ResultPill(
                  label: 'Mínimo',
                  value: currency.format(result.minimumPrice),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PricingSummary extends StatelessWidget {
  const _PricingSummary({
    required this.platform,
    required this.result,
    required this.currency,
  });

  final PricingPlatform platform;
  final PricingResult result;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo do cálculo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            _SummaryLine(label: 'Canal', value: platform.name),
            _SummaryLine(
              label: 'Custo',
              value: currency.format(result.productCost),
            ),
            _SummaryLine(
              label: 'Custos adicionais',
              value: currency.format(result.additionalCosts),
            ),
            _SummaryLine(
              label: 'Taxas fixas',
              value: currency.format(result.fixedFees),
            ),
            _SummaryLine(
              label: 'Taxas percentuais',
              value: currency.format(result.percentageFees),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PricingShellGrid extends StatelessWidget {
  const _PricingShellGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 3 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.15 : 4,
          children: const [
            _PricingShellTile(
              icon: Icons.storefront_outlined,
              title: 'Plataformas',
              detail: 'Taxas por canal',
              value: '0',
              color: AppTheme.primaryBlue,
            ),
            _PricingShellTile(
              icon: Icons.percent,
              title: 'Taxas',
              detail: 'Fixas e percentuais',
              value: '0',
              color: AppTheme.warning,
            ),
            _PricingShellTile(
              icon: Icons.compare_arrows_outlined,
              title: 'Comparações',
              detail: 'Lucro por canal',
              value: '0',
              color: AppTheme.aqua,
            ),
          ],
        );
      },
    );
  }
}

class _PricingShellTile extends StatelessWidget {
  const _PricingShellTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
