import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../shared/widgets/page_container.dart';

class StockMovementsPage extends StatelessWidget {
  const StockMovementsPage({super.key});

  static const routePath = '/stock';
  static const routeName = 'stock';

  @override
  Widget build(BuildContext context) {
    return const InventoryPlaceholderPage(
      title: 'Estoque',
      subtitle: 'Entradas, saídas, perdas e ajustes com histórico',
      icon: Icons.sync_alt_outlined,
      actionIcon: Icons.add_circle_outline,
      primaryActionLabel: 'Registrar movimento',
      accentColor: AppTheme.aqua,
      stats: [
        PlaceholderStat('Entradas', '0', Icons.add_circle_outline),
        PlaceholderStat('Saídas', '0', Icons.remove_circle_outline),
        PlaceholderStat('Ajustes', '0', Icons.tune_outlined),
      ],
      emptyTitle: 'Sem movimentações registradas',
      emptyDescription:
          'Cada alteração futura no saldo criará uma movimentação para preservar o histórico.',
      nextSteps: [
        'Registrar entrada quando houver compra ou reposição.',
        'Registrar saída por venda, perda, brinde ou uso próprio.',
        'Bloquear alterações sem histórico direto no saldo do produto.',
      ],
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
      subtitle: 'Conferência física semanal e divergências',
      icon: Icons.fact_check_outlined,
      actionIcon: Icons.playlist_add_check,
      primaryActionLabel: 'Iniciar contagem',
      accentColor: AppTheme.success,
      stats: [
        PlaceholderStat('Abertas', '0', Icons.pending_actions_outlined),
        PlaceholderStat('Divergências', '0', Icons.report_problem_outlined),
        PlaceholderStat('Finalizadas', '0', Icons.task_alt),
      ],
      emptyTitle: 'Sem contagens abertas',
      emptyDescription:
          'Ao finalizar uma contagem, diferenças poderão gerar ajustes de estoque automaticamente.',
      nextSteps: [
        'Escolher produtos que entram na contagem.',
        'Informar quantidade esperada e encontrada.',
        'Gerar ajuste quando existir divergência.',
      ],
    );
  }
}

class InventoryPlaceholderPage extends StatelessWidget {
  const InventoryPlaceholderPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionIcon,
    required this.primaryActionLabel,
    required this.accentColor,
    required this.stats,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.nextSteps,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData actionIcon;
  final String primaryActionLabel;
  final Color accentColor;
  final List<PlaceholderStat> stats;
  final String emptyTitle;
  final String emptyDescription;
  final List<String> nextSteps;

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
              icon: Icon(actionIcon),
              label: Text(primaryActionLabel),
            ),
          ),
          const SizedBox(height: 20),
          _ModuleSummary(
            title: title,
            subtitle: subtitle,
            icon: icon,
            accentColor: accentColor,
          ),
          const SizedBox(height: 20),
          _StatsRow(stats: stats, accentColor: accentColor),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              final content = [
                _EmptyState(
                  icon: icon,
                  title: emptyTitle,
                  description: emptyDescription,
                  accentColor: accentColor,
                ),
                _NextSteps(steps: nextSteps),
              ];

              if (!isWide) {
                return Column(
                  children: [
                    content.first,
                    const SizedBox(height: 12),
                    content.last,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: content.first),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: content.last),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PlaceholderStat {
  const PlaceholderStat(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _ModuleSummary extends StatelessWidget {
  const _ModuleSummary({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.accentColor});

  final List<PlaceholderStat> stats;
  final Color accentColor;

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
                  child: _StatTile(stat: stat, accentColor: accentColor),
                ),
                if (stat != stats.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final stat in stats) ...[
              Expanded(
                child: _StatTile(stat: stat, accentColor: accentColor),
              ),
              if (stat != stats.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.accentColor});

  final PlaceholderStat stat;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(stat.icon, color: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat.value,
                    style: Theme.of(context).textTheme.headlineSmall,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 260,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 34, color: accentColor),
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextSteps extends StatelessWidget {
  const _NextSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Próximos passos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final step in steps) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (step != steps.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
