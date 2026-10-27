import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_state.dart';
import '../features/inventory/data/stock_count_repository.dart';
import '../features/inventory/domain/stock_count.dart';
import '../features/inventory/presentation/stock_count_comparison_panel.dart';
import '../shared/widgets/page_container.dart';

class StockCountComparisonPage extends ConsumerWidget {
  const StockCountComparisonPage({super.key, required this.countId});
  final String countId;
  static const routePath = '/counts/:countId/compare';
  static const routeName = 'countComparison';

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Comparar relatórios',
          subtitle: 'Confira as diferenças entre duas contagens de estoque',
          trailing: OutlinedButton.icon(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/counts');
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar'),
          ),
        ),
        const SizedBox(height: 20),
        ref
            .watch(authStateProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const _ComparisonMessage(
                'Não foi possível carregar sua conta.',
              ),
              data: (user) {
                final companyId = user?.activeCompanyId;
                if (user == null || companyId == null || companyId.isEmpty) {
                  return const _ComparisonMessage(
                    'Entre na sua conta e selecione uma empresa para comparar relatórios.',
                  );
                }
                return ref
                    .watch(stockCountsProvider(companyId))
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => _ComparisonMessage(
                        'Não foi possível carregar os relatórios.',
                        onRetry: () =>
                            ref.invalidate(stockCountsProvider(companyId)),
                      ),
                      data: (reports) {
                        final source = reports
                            .where((r) => r.id == countId)
                            .firstOrNull;
                        if (source == null) {
                          return const _ComparisonMessage(
                            'Relatório não encontrado nesta empresa. Volte ao histórico e abra outro relatório.',
                          );
                        }
                        if (source.status != StockCountStatus.completed) {
                          return const _ComparisonMessage(
                            'Conclua a contagem antes de comparar seu relatório.',
                          );
                        }
                        return StockCountComparisonPanel(
                          key: ValueKey('${user.id}-$companyId-$countId'),
                          reports: reports,
                          sourceReportId: source.id,
                        );
                      },
                    );
              },
            ),
      ],
    ),
  );
}

class _ComparisonMessage extends StatelessWidget {
  const _ComparisonMessage(this.message, {this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.compare_arrows),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    ),
  );
}
