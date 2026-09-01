import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
            subtitle: 'Calculadora determinística',
            trailing: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Novo cálculo'),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 28,
                runSpacing: 20,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _PricingValue(
                    label: 'Preço recomendado',
                    value: currency.format(result.salePrice),
                  ),
                  _PricingValue(
                    label: 'Lucro',
                    value: currency.format(result.profit),
                  ),
                  _PricingValue(
                    label: 'Margem',
                    value: NumberFormat.percentPattern(
                      'pt_BR',
                    ).format(result.margin),
                  ),
                  _PricingValue(
                    label: 'Preço mínimo',
                    value: currency.format(result.minimumPrice),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _PricingShellGrid(),
        ],
      ),
    );
  }
}

class _PricingValue extends StatelessWidget {
  const _PricingValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
          childAspectRatio: isWide ? 2.1 : 4,
          children: const [
            _PricingShellTile(
              icon: Icons.storefront_outlined,
              title: 'Plataformas',
              value: '0',
            ),
            _PricingShellTile(icon: Icons.percent, title: 'Taxas', value: '0'),
            _PricingShellTile(
              icon: Icons.compare_arrows_outlined,
              title: 'Comparações',
              value: '0',
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
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
