import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_theme.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/domain/app_user.dart';
import '../features/inventory/data/product_repository.dart';
import '../features/inventory/data/stock_count_repository.dart';
import '../features/inventory/domain/product.dart';
import '../features/inventory/domain/stock_count.dart';
import '../features/inventory/presentation/stock_count_report.dart';
import '../shared/widgets/page_container.dart';

export '../features/inventory/data/stock_count_repository.dart'
    show stockCountsProvider;

final countProductsProvider = StreamProvider.family<List<Product>, String>(
  (ref, companyId) =>
      ref.watch(productRepositoryProvider).watchProducts(companyId),
);

class StockCountsPage extends ConsumerWidget {
  const StockCountsPage({super.key});
  static const routePath = '/counts';
  static const routeName = 'counts';

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(authStateProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const _CountMessage('Não foi possível carregar sua conta.'),
        data: (user) {
          if (user == null) {
            return const _CountMessage(
              'Entre na sua conta para consultar as contagens.',
            );
          }
          final companyId = user.activeCompanyId;
          if (companyId == null || companyId.isEmpty) {
            return const PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Contagens',
                    subtitle: 'Conferência física semanal e relatórios',
                  ),
                  SizedBox(height: 20),
                  _CountMessage(
                    'Cadastre seus produtos em uma empresa para iniciar a conferência.',
                  ),
                ],
              ),
            );
          }
          return _CompanyCounts(
            key: ValueKey('${user.id}-$companyId'),
            user: user,
            companyId: companyId,
          );
        },
      );
}

class _CompanyCounts extends ConsumerStatefulWidget {
  const _CompanyCounts({
    super.key,
    required this.user,
    required this.companyId,
  });
  final AppUser user;
  final String companyId;
  @override
  ConsumerState<_CompanyCounts> createState() => _CompanyCountsState();
}

class _CompanyCountsState extends ConsumerState<_CompanyCounts> {
  bool _starting = false;
  String? _editingCountId;
  StockCount? _savedProgress;
  final _openCountsKey = GlobalKey();
  String _historySearch = '';
  int _historyLimit = 10;

  @override
  Widget build(BuildContext context) {
    final countsState = ref.watch(stockCountsProvider(widget.companyId));
    final productsState = ref.watch(countProductsProvider(widget.companyId));
    final products =
        productsState.asData?.value.where((p) => p.isActive).toList() ??
        <Product>[];
    final counts = countsState.asData?.value ?? <StockCount>[];
    final open = counts.where((c) => c.isOpen).map((count) {
      // An immediate resume can happen before the stream delivers the saved revision.
      final saved = _savedProgress;
      return saved != null &&
              saved.id == count.id &&
              saved.revision > count.revision
          ? saved
          : count;
    }).toList();
    final reports =
        counts.where((c) => c.status == StockCountStatus.completed).toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.startedAt).compareTo(
              a.completedAt ?? a.startedAt,
            ),
          );
    final matching = reports
        .where(
          (r) => '${countTitle(r)} ${r.responsibleName} ${r.note}'
              .toLowerCase()
              .contains(_historySearch.toLowerCase()),
        )
        .toList();
    final canStart =
        !_starting &&
        countsState.hasValue &&
        productsState.hasValue &&
        open.isEmpty &&
        products.isNotEmpty;

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Contagens',
            subtitle: 'Conferência física semanal, ajustes e relatórios',
            trailing: FilledButton.icon(
              onPressed: canStart ? () => _start(products) : null,
              icon: _starting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add_check),
              label: const Text('Iniciar contagem'),
            ),
          ),
          const SizedBox(height: 20),
          countsState.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => _CountMessage(
              'Não foi possível carregar as contagens.',
              onRetry: () =>
                  ref.invalidate(stockCountsProvider(widget.companyId)),
            ),
            data: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CountsOverview(reports: reports, openCount: open.length),
                const SizedBox(height: 20),
                if (productsState.hasError)
                  _CountMessage(
                    'Não foi possível carregar os produtos.',
                    onRetry: () =>
                        ref.invalidate(countProductsProvider(widget.companyId)),
                  ),
                if (open.isEmpty)
                  _CountMessage(
                    productsState.isLoading
                        ? 'Carregando produtos…'
                        : products.isEmpty
                        ? 'Cadastre produtos ativos para iniciar sua primeira contagem.'
                        : 'Nenhuma contagem em andamento. Inicie a conferência e informe a quantidade encontrada de cada produto.',
                  )
                else
                  KeyedSubtree(
                    key: _openCountsKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final count in open)
                          if (_editingCountId == count.id)
                            _CountEditor(
                              key: ValueKey(count.id),
                              count: count,
                              repository: ref.watch(
                                stockCountRepositoryProvider,
                              ),
                              user: widget.user,
                              onProgressSaved: (saved) {
                                setState(() {
                                  _savedProgress = saved;
                                  _editingCountId = null;
                                });
                                _scrollToOpenCount();
                              },
                            )
                          else
                            _CountInProgressTile(
                              count: count,
                              onContinue: () {
                                setState(() => _editingCountId = count.id);
                                _scrollToOpenCount();
                              },
                            ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Histórico de relatórios',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cada contagem concluída gera um relatório com as quantidades daquela conferência.',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText:
                                'Buscar por código, data, responsável ou observação',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() {
                            _historySearch = value;
                            _historyLimit = 10;
                          }),
                        ),
                        const SizedBox(height: 16),
                        if (matching.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              reports.isEmpty
                                  ? 'Nenhum relatório salvo. Conclua a primeira contagem para começar o histórico.'
                                  : 'Nenhum relatório encontrado para esta busca.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        for (final report in matching.take(_historyLimit))
                          _ReportTile(report: report),
                        if (matching.length > _historyLimit)
                          TextButton(
                            onPressed: () =>
                                setState(() => _historyLimit += 10),
                            child: const Text('Mostrar mais relatórios'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(List<Product> products) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _StartCountDialog(products: products),
    );
    if (selected == null || !mounted) return;
    setState(() => _starting = true);
    try {
      final countId = await ref
          .read(stockCountRepositoryProvider)
          .start(
            companyId: widget.companyId,
            productIds: selected,
            userId: widget.user.id,
            responsibleName: widget.user.displayName ?? widget.user.email,
          );
      if (mounted) {
        setState(() => _editingCountId = countId);
        _scrollToOpenCount();
      }
    } catch (error) {
      if (mounted) _showCountError(context, error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _scrollToOpenCount() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final countContext = _openCountsKey.currentContext;
      if (countContext != null) {
        Scrollable.ensureVisible(
          countContext,
          duration: const Duration(milliseconds: 250),
          alignment: .1,
        );
      }
    });
  }
}

class _CountInProgressTile extends StatelessWidget {
  const _CountInProgressTile({required this.count, required this.onContinue});
  final StockCount count;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.pending_actions_outlined, color: colors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.code == null
                    ? 'Contagem em andamento'
                    : 'Contagem ${count.code} em andamento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${count.countedItems} de ${count.items.length} produtos conferidos',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              Text(
                'Iniciada em ${countDate(count.startedAt)} • ${count.responsibleName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
    final resume = OutlinedButton.icon(
      onPressed: onContinue,
      icon: const Icon(Icons.play_arrow_outlined),
      label: const Text('Continuar contagem'),
    );
    return Card(
      key: ValueKey('count-summary-${count.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onContinue,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 650
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: resume),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: summary),
                      const SizedBox(width: 20),
                      resume,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CountsOverview extends StatelessWidget {
  const _CountsOverview({required this.reports, required this.openCount});
  final List<StockCount> reports;
  final int openCount;
  @override
  Widget build(BuildContext context) {
    final latest = reports.firstOrNull;
    final days = latest == null
        ? null
        : DateTime.now()
              .difference(latest.completedAt ?? latest.startedAt)
              .inDays;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.deepBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Conferência semanal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            latest == null
                ? 'Comece sua primeira conferência física de estoque.'
                : 'Última contagem: ${countTitle(latest)} • ${days! >= 7 ? 'Hora de conferir novamente' : 'Conferência em dia'}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 28,
            runSpacing: 16,
            children: [
              _OverviewNumber('Em andamento', '$openCount'),
              _OverviewNumber('Relatórios salvos', '${reports.length}'),
              _OverviewNumber(
                'Divergências na última',
                latest == null ? '—' : '${latest.divergentItems}',
              ),
              _OverviewNumber(
                'Unidades na última',
                latest == null ? '—' : '${latest.totalUnits}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewNumber extends StatelessWidget {
  const _OverviewNumber(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .75))),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _StartCountDialog extends StatefulWidget {
  const _StartCountDialog({required this.products});
  final List<Product> products;
  @override
  State<_StartCountDialog> createState() => _StartCountDialogState();
}

class _StartCountDialogState extends State<_StartCountDialog> {
  late final Set<String> _selected =
      widget.products.length <= StockCountRepository.maxProducts
      ? widget.products.map((p) => p.id).toSet()
      : <String>{};
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final visible = widget.products
        .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return AlertDialog(
      title: const Text('Iniciar contagem'),
      content: SizedBox(
        width: 600,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selecione os produtos da conferência. As quantidades registradas serão preservadas ao iniciar.',
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar produto',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selected.length} de ${StockCountRepository.maxProducts} produtos por contagem',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('Limpar'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final product in visible)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.name),
                      subtitle: Text(
                        '${product.currentStock} ${product.unit} registrados',
                      ),
                      value: _selected.contains(product.id),
                      onChanged: (value) => setState(() {
                        if (value == true &&
                            _selected.length <
                                StockCountRepository.maxProducts) {
                          _selected.add(product.id);
                        } else if (value != true) {
                          _selected.remove(product.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          child: const Text('Começar conferência'),
        ),
      ],
    );
  }
}

class _CountEditor extends StatefulWidget {
  const _CountEditor({
    super.key,
    required this.count,
    required this.repository,
    required this.user,
    required this.onProgressSaved,
  });
  final StockCount count;
  final StockCountRepository repository;
  final AppUser user;
  final ValueChanged<StockCount> onProgressSaved;
  @override
  State<_CountEditor> createState() => _CountEditorState();
}

class _CountEditorState extends State<_CountEditor> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _quantities;
  late final List<TextEditingController> _reasons;
  bool _busy = false;
  bool _dirty = false;
  String _search = '';
  late StockCount _baseCount;

  @override
  void initState() {
    super.initState();
    _baseCount = widget.count;
    _quantities = [
      for (final item in widget.count.items)
        TextEditingController(text: item.countedQuantity?.toString() ?? ''),
    ];
    _reasons = [
      for (final item in widget.count.items)
        TextEditingController(text: item.reason),
    ];
    for (final controller in [..._quantities, ..._reasons]) {
      controller.addListener(() {
        if (mounted) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [..._quantities, ..._reasons]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<StockCountItem> get _items => [
    for (var i = 0; i < _baseCount.items.length; i++)
      _baseCount.items[i].withCount(
        int.tryParse(_quantities[i].text),
        _reasons[i].text.trim(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final counted = items.where((i) => i.isCounted).length;
    final divergent = items
        .where((i) => i.isCounted && i.difference != 0)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.count.code == null
                    ? 'Contagem em andamento'
                    : 'Contagem ${widget.count.code} em andamento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Iniciada em ${countDate(widget.count.startedAt)} • ${widget.count.responsibleName}',
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: items.isEmpty ? 0 : counted / items.length,
              ),
              const SizedBox(height: 8),
              Text(
                '$counted de ${items.length} produtos conferidos • $divergent divergências',
              ),
              const SizedBox(height: 16),
              const Text(
                'Informe a quantidade física, inclusive zero. Concluir salva apenas o relatório; o ajuste de estoque é opcional ao visualizá-lo.',
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Localizar produto na contagem',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              AbsorbPointer(
                absorbing: _busy,
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      // Keep hidden form fields mounted so validation covers the whole count.
                      Offstage(
                        offstage: !items[i].productName.toLowerCase().contains(
                          _search.toLowerCase(),
                        ),
                        child: _editorRow(i, items[i]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _dirty
                    ? 'Há alterações não salvas. Salve o progresso antes de sair.'
                    : 'Progresso salvo. Você pode continuar esta contagem depois.',
              ),
              const SizedBox(height: 14),
              if (widget.count.revision != _baseCount.revision)
                TextButton.icon(
                  onPressed: _busy ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recarregar progresso de outra sessão'),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancelar contagem'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _save(false),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar progresso'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy || counted != items.length
                        ? null
                        : () => _save(true),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Concluir e gerar relatório'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editorRow(int index, StockCountItem item) {
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.productName, style: Theme.of(context).textTheme.titleMedium),
        Text('Registrado: ${item.expectedQuantity} ${item.unit}'),
      ],
    );
    final input = TextFormField(
      enabled: !_busy,
      key: ValueKey('count-quantity-${item.productId}'),
      controller: _quantities[index],
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(labelText: 'Encontrado (${item.unit})'),
      validator: (value) {
        if (value == null || value.isEmpty) return null;
        final quantity = int.tryParse(value);
        return quantity == null || quantity < 0 || quantity > 1000000000
            ? 'Quantidade inválida.'
            : null;
      },
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 620
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      name,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: input),
                          const SizedBox(width: 12),
                          CountDifferenceBadge(
                            item.isCounted ? item.difference : null,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: name),
                      SizedBox(width: 160, child: input),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 130,
                        child: CountDifferenceBadge(
                          item.isCounted ? item.difference : null,
                        ),
                      ),
                    ],
                  ),
          ),
          if (item.isCounted && item.difference != 0 ||
              _reasons[index].text.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextFormField(
              enabled: !_busy,
              controller: _reasons[index],
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Observação da divergência (opcional)',
                counterText: '',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(bool complete) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final items = _items;
    if (complete) {
      final differences = items.where((i) => i.difference != 0).length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Concluir contagem?'),
          content: Text(
            'Um relatório será salvo para ${items.length} produtos. '
            '${differences == 0 ? 'Todos os itens conferem.' : '$differences produtos apresentam divergências.'} '
            'O estoque não será alterado agora. Se desejar, abra o relatório para ajustar as diferenças depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Revisar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar conclusão'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (complete) {
        await widget.repository.complete(
          count: _baseCount,
          items: items,
          userId: widget.user.id,
          userEmail: widget.user.email,
        );
      } else {
        await widget.repository.saveProgress(_baseCount, items);
      }
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _baseCount = _baseCount.withProgress(items, _baseCount.revision + 1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complete
                ? 'Contagem concluída. Relatório salvo no histórico.'
                : 'Progresso salvo.',
          ),
        ),
      );
      if (!complete) widget.onProgressSaved(_baseCount);
    } catch (error) {
      if (mounted) _showCountError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar contagem?'),
        content: const Text(
          'Esta conferência será encerrada sem ajustar o estoque ou gerar relatório.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar contando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar contagem'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.cancel(widget.count);
    } catch (error) {
      if (mounted) _showCountError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (_dirty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recarregar progresso salvo?'),
          content: const Text(
            'Seu preenchimento ainda não salvo será substituído pelo progresso salvo mais recente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Manter preenchimento'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Recarregar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _baseCount = widget.count;
    for (var i = 0; i < _baseCount.items.length; i++) {
      _quantities[i].text =
          _baseCount.items[i].countedQuantity?.toString() ?? '';
      _reasons[i].text = _baseCount.items[i].reason;
    }
    setState(() => _dirty = false);
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});
  final StockCount report;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              countTitle(report),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${report.items.length} produtos • ${report.totalUnits} unidades • ${report.responsibleName}',
            ),
            Text(
              '${report.divergentItems} divergências • ${report.missingUnits} faltas • ${report.surplusUnits} sobras',
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () => showStockCountReport(context, report),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Ver relatório'),
        ),
      ],
    ),
  );
}

class _CountMessage extends StatelessWidget {
  const _CountMessage(this.message, {this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
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

void _showCountError(BuildContext context, Object error) {
  final message = error is StateError
      ? error.message
      : error is ArgumentError
      ? '${error.message}'
      : error is FirebaseException && error.code == 'permission-denied'
      ? 'Sem permissão para salvar a contagem. Confira o acesso à empresa e as regras do banco.'
      : error is FirebaseException && error.code == 'unavailable'
      ? 'Conecte-se à internet para salvar ou concluir a contagem.'
      : 'Não foi possível salvar a contagem. Seu preenchimento foi mantido; tente novamente.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
