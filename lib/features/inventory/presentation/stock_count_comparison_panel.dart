import 'package:flutter/material.dart';
import '../../../app/theme/app_theme.dart';
import '../application/stock_count_comparison.dart';
import '../domain/stock_count.dart';
import 'stock_count_report.dart';

class StockCountComparisonPanel extends StatefulWidget {
  const StockCountComparisonPanel({
    super.key,
    required this.reports,
    required this.sourceReportId,
  });
  final List<StockCount> reports;
  final String sourceReportId;
  @override
  State<StockCountComparisonPanel> createState() =>
      _StockCountComparisonPanelState();
}

class _StockCountComparisonPanelState extends State<StockCountComparisonPanel> {
  String? _otherId;
  bool _onlyChanges = true;

  @override
  void didUpdateWidget(covariant StockCountComparisonPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceReportId != widget.sourceReportId) _otherId = null;
  }

  @override
  Widget build(BuildContext context) {
    final reports = widget.reports
        .where((r) => r.status == StockCountStatus.completed)
        .toList();
    final source = reports
        .where((r) => r.id == widget.sourceReportId)
        .firstOrNull;
    if (source == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'O relatório de origem não está disponível. Volte ao histórico e selecione outro relatório.',
          ),
        ),
      );
    }
    final options =
        reports
            .where((r) => r.id != source.id && r.companyId == source.companyId)
            .toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.startedAt).compareTo(
              a.completedAt ?? a.startedAt,
            ),
          );
    final other = options.where((r) => r.id == _otherId).firstOrNull;
    final sourceFirst =
        other == null ||
        !(source.completedAt ?? source.startedAt).isAfter(
          other.completedAt ?? other.startedAt,
        );
    final before = other == null || sourceFirst ? source : other;
    final after = other == null || sourceFirst ? other : source;
    final differences = after == null
        ? <StockCountDifference>[]
        : compareStockCounts(before, after);
    final visible = differences
        .where((row) => !_onlyChanges || row.changed)
        .toList();
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Relatório aberto',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    countTitle(source),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${source.items.length} produtos • ${source.responsibleName}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (options.isEmpty)
              const Text(
                'Conclua outra contagem para comparar dois relatórios.',
              )
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('compare-with-${other?.id ?? 'none'}'),
                initialValue: other?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Comparar com',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                hint: const Text('Escolha outro relatório'),
                items: [
                  for (final report in options)
                    DropdownMenuItem(
                      value: report.id,
                      child: Text(
                        countTitle(report),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _otherId = value),
              ),
              const SizedBox(height: 14),
              if (other == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Selecione o segundo relatório para visualizar as diferenças.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                Text(
                  '${countTitle(before)} → ${countTitle(after!)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Os relatórios são organizados do anterior para o mais recente, independentemente de qual você abriu.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar apenas diferenças'),
                  value: _onlyChanges,
                  onChanged: (value) =>
                      setState(() => _onlyChanges = value ?? true),
                ),
                Text(
                  '${differences.where((r) => r.changed).length} produtos com diferenças • '
                  '${differences.where((r) => r.added).length} incluídos • '
                  '${differences.where((r) => r.removed).length} fora da nova contagem',
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhuma diferença entre os produtos comparados.',
                    ),
                  ),
                for (final row in visible) _ComparisonRow(row: row),
                const SizedBox(height: 12),
                const Text(
                  'Variação registrada = esperado na conferência recente − encontrado na anterior. '
                  'Pode incluir vendas, reposições e outros ajustes. Divergência física = encontrado − esperado em cada contagem. '
                  'Produtos fora de uma conferência não são tratados como estoque zero.',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.row});
  final StockCountDifference row;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget side(StockCountItem? item, bool old) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (old ? colors.error : AppTheme.success).withValues(alpha: .06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            old ? '− Anterior' : '+ Mais recente',
            style: TextStyle(
              color: old ? colors.error : AppTheme.success,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (item == null)
            const Text('Não participa desta contagem')
          else ...[
            Text(item.productName),
            Text('Esperado: ${item.expectedQuantity} ${item.unit}'),
            Text(
              'Encontrado: ${item.countedQuantity} ${item.unit}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            CountDifferenceBadge(item.difference),
            if (item.reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(item.reason),
              ),
          ],
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(row.name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                row.added
                    ? 'Incluído na contagem'
                    : row.removed
                    ? 'Fora da nova contagem'
                    : !row.comparable
                    ? 'Unidade alterada; quantidades não comparáveis'
                    : 'Variação física: ${signedQuantity(row.variation!)} • Registrada: ${signedQuantity(row.registeredVariation!)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 600
                ? Column(
                    children: [
                      side(row.before, true),
                      const SizedBox(height: 8),
                      side(row.after, false),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: side(row.before, true)),
                      const SizedBox(width: 10),
                      Expanded(child: side(row.after, false)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
