import 'package:flutter/material.dart';

import '../shared/widgets/page_container.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  static const routePath = '/products';
  static const routeName = 'products';

  @override
  Widget build(BuildContext context) {
    return const InventoryPlaceholderPage(
      title: 'Produtos',
      subtitle: 'Cadastro e consulta',
      icon: Icons.inventory_2_outlined,
      primaryActionLabel: 'Novo produto',
      stats: [
        PlaceholderStat('Ativos', '0'),
        PlaceholderStat('Estoque baixo', '0'),
        PlaceholderStat('Sem estoque', '0'),
      ],
      emptyTitle: 'Sem produtos cadastrados',
    );
  }
}

class StockMovementsPage extends StatelessWidget {
  const StockMovementsPage({super.key});

  static const routePath = '/stock';
  static const routeName = 'stock';

  @override
  Widget build(BuildContext context) {
    return const InventoryPlaceholderPage(
      title: 'Estoque',
      subtitle: 'Entradas, saídas e ajustes',
      icon: Icons.sync_alt_outlined,
      primaryActionLabel: 'Registrar movimento',
      stats: [
        PlaceholderStat('Entradas', '0'),
        PlaceholderStat('Saídas', '0'),
        PlaceholderStat('Ajustes', '0'),
      ],
      emptyTitle: 'Sem movimentações registradas',
    );
  }
}

class StockCountsPage extends StatelessWidget {
  const StockCountsPage({super.key});

  static const routePath = '/counts';
  static const routeName = 'counts';

  @override
  Widget build(BuildContext context) {
    return const InventoryPlaceholderPage(
      title: 'Contagens',
      subtitle: 'Conferência física',
      icon: Icons.fact_check_outlined,
      primaryActionLabel: 'Iniciar contagem',
      stats: [
        PlaceholderStat('Abertas', '0'),
        PlaceholderStat('Divergências', '0'),
        PlaceholderStat('Finalizadas', '0'),
      ],
      emptyTitle: 'Sem contagens abertas',
    );
  }
}

class InventoryPlaceholderPage extends StatelessWidget {
  const InventoryPlaceholderPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryActionLabel,
    required this.stats,
    required this.emptyTitle,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryActionLabel;
  final List<PlaceholderStat> stats;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: title,
            subtitle: subtitle,
            trailing: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add),
              label: Text(primaryActionLabel),
            ),
          ),
          const SizedBox(height: 24),
          _StatsRow(stats: stats),
          const SizedBox(height: 24),
          _EmptyState(icon: icon, title: emptyTitle),
        ],
      ),
    );
  }
}

class PlaceholderStat {
  const PlaceholderStat(this.label, this.value);

  final String label;
  final String value;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<PlaceholderStat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;

        if (isCompact) {
          return Column(
            children: [
              for (final stat in stats) ...[
                SizedBox(
                  width: double.infinity,
                  child: _StatTile(stat: stat),
                ),
                if (stat != stats.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final stat in stats) ...[
              Expanded(child: _StatTile(stat: stat)),
              if (stat != stats.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final PlaceholderStat stat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stat.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(stat.value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 220,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
