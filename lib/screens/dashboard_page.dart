import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/bootstrap/firebase_bootstrap.dart';
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
            subtitle: 'Visão inicial do estoque',
            trailing: _FirebaseStatusChip(firebase),
          ),
          const SizedBox(height: 24),
          const _QuickActions(),
          const SizedBox(height: 24),
          _MetricGrid(
            metrics: [
              DashboardMetric(
                label: 'Produtos',
                value: '0',
                icon: Icons.inventory_2_outlined,
              ),
              DashboardMetric(
                label: 'Valor em custo',
                value: currency.format(0),
                icon: Icons.payments_outlined,
              ),
              DashboardMetric(
                label: 'Estoque baixo',
                value: '0',
                icon: Icons.warning_amber_outlined,
              ),
              DashboardMetric(
                label: 'Movimentações',
                value: '0',
                icon: Icons.sync_alt_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
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
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
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
            childAspectRatio: columns == 1 ? 4 : 2.4,
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
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: Icon(metric.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                ],
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
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/products'),
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Novo produto'),
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
        final isWide = constraints.maxWidth >= 800;
        final children = [
          const _DashboardPanel(
            title: 'Alertas',
            icon: Icons.notifications_none,
            lines: ['Nenhum alerta'],
          ),
          const _DashboardPanel(
            title: 'Reposição',
            icon: Icons.shopping_cart_outlined,
            lines: ['Nenhum item listado'],
          ),
          const _DashboardPanel(
            title: 'Giro',
            icon: Icons.trending_up,
            lines: ['Sem vendas registradas'],
          ),
          const _DashboardPanel(
            title: 'Canais',
            icon: Icons.hub_outlined,
            lines: ['0 canais cadastrados'],
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                if (child != children.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3.4,
          children: children,
        );
      },
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.icon,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final line in lines)
              Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
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
      ),
      label: Text(result.message),
      backgroundColor: isReady
          ? colorScheme.primaryContainer
          : colorScheme.tertiaryContainer,
      labelStyle: TextStyle(
        color: isReady
            ? colorScheme.onPrimaryContainer
            : colorScheme.onTertiaryContainer,
      ),
      side: BorderSide.none,
    );
  }
}
