import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_theme.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/domain/app_user.dart';
import '../features/company/data/company_repository.dart';
import '../features/inventory/application/inventory_service.dart';
import '../features/inventory/data/product_repository.dart';
import '../features/inventory/data/stock_movement_repository.dart';
import '../features/inventory/domain/product.dart';
import '../features/inventory/domain/stock_movement.dart';
import '../shared/widgets/page_container.dart';

final stockMovementsProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, companyId) {
      return ref
          .watch(stockMovementRepositoryProvider)
          .watchRecentMovements(companyId);
    });

final stockProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  companyId,
) {
  return ref.watch(productRepositoryProvider).watchProducts(companyId);
});

class StockMovementsPage extends ConsumerStatefulWidget {
  const StockMovementsPage({super.key});

  static const routePath = '/stock';
  static const routeName = 'stock';

  @override
  ConsumerState<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends ConsumerState<StockMovementsPage> {
  String _search = '';
  _MovementFilters _filters = const _MovementFilters();
  _MovementSort _sort = _MovementSort.newestFirst;
  int _currentPage = 1;
  String? _localCompanyId;
  bool _preparingCompany = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const _StockMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar sua conta',
        description: 'Atualize a página e tente novamente.',
      ),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final companyId = _localCompanyId ?? user.activeCompanyId;
        return _buildPage(user, companyId);
      },
    );
  }

  Widget _buildPage(AppUser user, String? companyId) {
    final productsState = companyId == null
        ? const AsyncValue<List<Product>>.data([])
        : ref.watch(stockProductsProvider(companyId));
    final movementsState = companyId == null
        ? const AsyncValue<List<StockMovement>>.data([])
        : ref.watch(stockMovementsProvider(companyId));
    final products = productsState.maybeWhen(
      data: (value) => value,
      orElse: () => const <Product>[],
    );

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Movimentações',
            subtitle: 'Entradas, saídas, perdas e ajustes com histórico',
            trailing: FilledButton.icon(
              onPressed: _preparingCompany
                  ? null
                  : () => _openMovementForm(user, products),
              icon: _preparingCompany
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: const Text('Registrar movimento'),
            ),
          ),
          const SizedBox(height: 20),
          productsState.when(
            loading: () => const _StockLoading(),
            error: (error, stackTrace) => const _StockMessage(
              icon: Icons.inventory_2_outlined,
              title: 'Não foi possível carregar os produtos',
              description: 'Atualize a página e tente novamente.',
            ),
            data: (products) => movementsState.when(
              loading: () => const _StockLoading(),
              error: (error, stackTrace) => const _StockMessage(
                icon: Icons.sync_problem_outlined,
                title: 'Não foi possível carregar o histórico',
                description: 'Atualize a página e tente novamente.',
              ),
              data: (movements) => _StockContent(
                products: products,
                movements: movements,
                search: _search,
                filters: _filters,
                sort: _sort,
                currentPage: _currentPage,
                onSearchChanged: (value) => setState(() {
                  _search = value;
                  _currentPage = 1;
                }),
                onFiltersChanged: (value) => setState(() {
                  _filters = value;
                  _currentPage = 1;
                }),
                onOpenFilters: () => _openFilters(products),
                onSortChanged: (value) => setState(() {
                  _sort = value;
                  _currentPage = 1;
                }),
                onPageChanged: (value) => setState(() => _currentPage = value),
                onRegisterMovement: () => _openMovementForm(user, products),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters(List<Product> products) async {
    final result = await showDialog<_MovementFilters>(
      context: context,
      builder: (context) => _AdvancedMovementFiltersDialog(
        initialFilters: _filters,
        products: products,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _filters = result;
        _currentPage = 1;
      });
    }
  }

  Future<void> _openMovementForm(
    AppUser user,
    List<Product> loadedProducts,
  ) async {
    final companyId = await _ensureCompany(user);
    if (!mounted || companyId == null) return;

    final activeProducts = loadedProducts
        .where((product) => product.isActive)
        .toList(growable: false);
    if (activeProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre pelo menos um produto ativo antes de movimentar o estoque.',
          ),
        ),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MovementFormDialog(
        companyId: companyId,
        userId: user.id,
        products: activeProducts,
        inventoryService: ref.read(inventoryServiceProvider),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimentação registrada com sucesso.')),
      );
    }
  }

  Future<String?> _ensureCompany(AppUser user) async {
    final existingCompanyId = _localCompanyId ?? user.activeCompanyId;
    if (existingCompanyId != null && existingCompanyId.isNotEmpty) {
      return existingCompanyId;
    }

    setState(() => _preparingCompany = true);
    try {
      final companyId = await ref
          .read(companyRepositoryProvider)
          .ensureDefaultCompany(user.id);
      if (mounted) setState(() => _localCompanyId = companyId);
      return companyId;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_stockErrorMessage(error))));
      }
      return null;
    } finally {
      if (mounted) setState(() => _preparingCompany = false);
    }
  }
}

const _stockOperationsPerPage = 15;

enum _MovementFilter { all, inbound, outbound, adjustments }

enum _MovementPeriod { all, today, last7Days, last30Days, custom }

enum _MovementObservationFilter { all, withObservation, withoutObservation }

enum _MovementSort {
  newestFirst,
  oldestFirst,
  mostProductsFirst,
  fewestProductsFirst,
  inboundFirst,
  outboundFirst,
}

extension _MovementFilterX on _MovementFilter {
  String get label {
    return switch (this) {
      _MovementFilter.all => 'Todos',
      _MovementFilter.inbound => 'Entradas',
      _MovementFilter.outbound => 'Saídas',
      _MovementFilter.adjustments => 'Ajustes',
    };
  }
}

extension _MovementPeriodX on _MovementPeriod {
  String get label {
    return switch (this) {
      _MovementPeriod.all => 'Todo o período',
      _MovementPeriod.today => 'Hoje',
      _MovementPeriod.last7Days => 'Últimos 7 dias',
      _MovementPeriod.last30Days => 'Últimos 30 dias',
      _MovementPeriod.custom => 'Período personalizado',
    };
  }
}

extension _MovementObservationFilterX on _MovementObservationFilter {
  String get label {
    return switch (this) {
      _MovementObservationFilter.all => 'Todas',
      _MovementObservationFilter.withObservation => 'Com observação',
      _MovementObservationFilter.withoutObservation => 'Sem observação',
    };
  }
}

extension _MovementSortX on _MovementSort {
  String get label {
    return switch (this) {
      _MovementSort.newestFirst => 'Data: mais recentes',
      _MovementSort.oldestFirst => 'Data: mais antigas',
      _MovementSort.mostProductsFirst => 'Produtos: maior quantidade',
      _MovementSort.fewestProductsFirst => 'Produtos: menor quantidade',
      _MovementSort.inboundFirst => 'Operação: entradas primeiro',
      _MovementSort.outboundFirst => 'Operação: saídas primeiro',
    };
  }
}

class _MovementFilters {
  const _MovementFilters({
    this.operation = _MovementFilter.all,
    this.type,
    this.period = _MovementPeriod.all,
    this.customPeriod,
    this.productIds = const <String>{},
    this.minimumProducts,
    this.maximumProducts,
    this.observation = _MovementObservationFilter.all,
  });

  final _MovementFilter operation;
  final StockMovementType? type;
  final _MovementPeriod period;
  final DateTimeRange? customPeriod;
  final Set<String> productIds;
  final int? minimumProducts;
  final int? maximumProducts;
  final _MovementObservationFilter observation;

  int get activeCount {
    var count = 0;
    if (operation != _MovementFilter.all) count++;
    if (type != null) count++;
    if (period != _MovementPeriod.all) count++;
    if (productIds.isNotEmpty) count++;
    if (minimumProducts != null || maximumProducts != null) count++;
    if (observation != _MovementObservationFilter.all) count++;
    return count;
  }

  _MovementFilters copyWith({
    _MovementFilter? operation,
    StockMovementType? type,
    bool clearType = false,
    _MovementPeriod? period,
    DateTimeRange? customPeriod,
    bool clearCustomPeriod = false,
    Set<String>? productIds,
    int? minimumProducts,
    int? maximumProducts,
    bool clearProductRange = false,
    _MovementObservationFilter? observation,
  }) {
    return _MovementFilters(
      operation: operation ?? this.operation,
      type: clearType ? null : type ?? this.type,
      period: period ?? this.period,
      customPeriod: clearCustomPeriod
          ? null
          : customPeriod ?? this.customPeriod,
      productIds: productIds ?? this.productIds,
      minimumProducts: clearProductRange
          ? null
          : minimumProducts ?? this.minimumProducts,
      maximumProducts: clearProductRange
          ? null
          : maximumProducts ?? this.maximumProducts,
      observation: observation ?? this.observation,
    );
  }
}

class _StockOperation {
  const _StockOperation({required this.id, required this.items});

  final String id;
  final List<StockMovement> items;

  StockMovement get reference => items.first;
  StockMovementType get type => reference.type;
  DateTime get occurredAt => reference.occurredAt;
  String get reason => reference.reason;
  String get note => reference.note;
  bool get increasesStock => reference.increasesStock;
  bool get decreasesStock => reference.decreasesStock;
}

List<_StockOperation> _groupStockOperations(List<StockMovement> movements) {
  final groups = <String, List<StockMovement>>{};

  for (final movement in movements) {
    final operationId = movement.operationId;
    final key = operationId != null && operationId.isNotEmpty
        ? operationId
        : [
            'legacy',
            movement.occurredAt.microsecondsSinceEpoch,
            movement.type.code,
            movement.userId ?? '',
            movement.reason,
            movement.note,
            movement.sourceChannelId ?? '',
          ].join('|');
    groups.putIfAbsent(key, () => []).add(movement);
  }

  final operations = [
    for (final entry in groups.entries)
      _StockOperation(id: entry.key, items: List.unmodifiable(entry.value)),
  ];
  operations.sort(
    (first, second) => second.occurredAt.compareTo(first.occurredAt),
  );
  return operations;
}

class _StockContent extends StatelessWidget {
  const _StockContent({
    required this.products,
    required this.movements,
    required this.search,
    required this.filters,
    required this.sort,
    required this.currentPage,
    required this.onSearchChanged,
    required this.onFiltersChanged,
    required this.onOpenFilters,
    required this.onSortChanged,
    required this.onPageChanged,
    required this.onRegisterMovement,
  });

  final List<Product> products;
  final List<StockMovement> movements;
  final String search;
  final _MovementFilters filters;
  final _MovementSort sort;
  final int currentPage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_MovementFilters> onFiltersChanged;
  final VoidCallback onOpenFilters;
  final ValueChanged<_MovementSort> onSortChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onRegisterMovement;

  @override
  Widget build(BuildContext context) {
    final productsById = {for (final product in products) product.id: product};
    final operations = _groupStockOperations(movements);
    final normalizedSearch = search.trim().toLowerCase();
    final visibleOperations =
        operations.where((operation) {
          final matchesSearch =
              normalizedSearch.isEmpty ||
              operation.items.any((movement) {
                final productName =
                    productsById[movement.productId]?.name ??
                    'Produto removido';
                return productName.toLowerCase().contains(normalizedSearch);
              }) ||
              operation.type.label.toLowerCase().contains(normalizedSearch) ||
              operation.reason.toLowerCase().contains(normalizedSearch) ||
              operation.note.toLowerCase().contains(normalizedSearch);
          final matchesProducts =
              filters.productIds.isEmpty ||
              operation.items.any(
                (movement) => filters.productIds.contains(movement.productId),
              );
          final matchesMinimumProducts =
              filters.minimumProducts == null ||
              operation.items.length >= filters.minimumProducts!;
          final matchesMaximumProducts =
              filters.maximumProducts == null ||
              operation.items.length <= filters.maximumProducts!;
          final hasObservation =
              operation.reason.trim().isNotEmpty ||
              operation.note.trim().isNotEmpty;
          final matchesObservation = switch (filters.observation) {
            _MovementObservationFilter.all => true,
            _MovementObservationFilter.withObservation => hasObservation,
            _MovementObservationFilter.withoutObservation => !hasObservation,
          };

          return matchesSearch &&
              _matchesOperationFilter(operation, filters.operation) &&
              (filters.type == null || operation.type == filters.type) &&
              _matchesMovementPeriod(operation.occurredAt, filters) &&
              matchesProducts &&
              matchesMinimumProducts &&
              matchesMaximumProducts &&
              matchesObservation;
        }).toList()..sort(
          (first, second) => _compareStockOperations(first, second, sort),
        );
    final pageCount = (visibleOperations.length / _stockOperationsPerPage)
        .ceil();
    final safePage = visibleOperations.isEmpty
        ? 1
        : currentPage.clamp(1, pageCount);
    final firstIndex = (safePage - 1) * _stockOperationsPerPage;
    final pageOperations = visibleOperations
        .skip(firstIndex)
        .take(_stockOperationsPerPage)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StockStats(operations: operations),
        const SizedBox(height: 20),
        _MovementToolbar(
          search: search,
          activeFilterCount: filters.activeCount,
          sort: sort,
          onSearchChanged: onSearchChanged,
          onOpenFilters: onOpenFilters,
          onSortChanged: onSortChanged,
        ),
        if (filters.activeCount > 0) ...[
          const SizedBox(height: 10),
          _ActiveMovementFilters(
            filters: filters,
            productsById: productsById,
            onChanged: onFiltersChanged,
          ),
        ],
        const SizedBox(height: 12),
        if (products.isEmpty)
          _StockMessage(
            icon: Icons.inventory_2_outlined,
            title: 'Nenhum produto disponível',
            description:
                'Cadastre um produto na tela de Produtos antes de registrar movimentações.',
          )
        else if (movements.isEmpty)
          _StockEmptyState(onRegisterMovement: onRegisterMovement)
        else if (visibleOperations.isEmpty)
          const _StockMessage(
            icon: Icons.search_off_outlined,
            title: 'Nenhuma movimentação encontrada',
            description:
                'Ajuste a busca ou o filtro para ver outros registros.',
          )
        else ...[
          _MovementHistory(
            operations: pageOperations,
            productsById: productsById,
          ),
          const SizedBox(height: 10),
          _StockPagination(
            currentPage: safePage,
            pageCount: pageCount,
            operationCount: visibleOperations.length,
            onPageChanged: onPageChanged,
          ),
        ],
      ],
    );
  }
}

class _StockStats extends StatelessWidget {
  const _StockStats({required this.operations});

  final List<_StockOperation> operations;

  @override
  Widget build(BuildContext context) {
    final inbound = operations
        .where(
          (operation) =>
              operation.type != StockMovementType.adjustment &&
              operation.increasesStock,
        )
        .length;
    final outbound = operations
        .where(
          (operation) =>
              operation.type != StockMovementType.adjustment &&
              operation.decreasesStock,
        )
        .length;
    final adjustments = operations
        .where((operation) => operation.type == StockMovementType.adjustment)
        .length;

    return _StatsRow(
      accentColor: AppTheme.aqua,
      stats: [
        PlaceholderStat('Entradas', '$inbound', Icons.add_circle_outline),
        PlaceholderStat('Saídas', '$outbound', Icons.remove_circle_outline),
        PlaceholderStat('Ajustes', '$adjustments', Icons.tune_outlined),
      ],
    );
  }
}

class _MovementToolbar extends StatelessWidget {
  const _MovementToolbar({
    required this.search,
    required this.activeFilterCount,
    required this.sort,
    required this.onSearchChanged,
    required this.onOpenFilters,
    required this.onSortChanged,
  });

  final String search;
  final int activeFilterCount;
  final _MovementSort sort;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilters;
  final ValueChanged<_MovementSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final searchField = TextFormField(
      initialValue: search,
      onChanged: onSearchChanged,
      decoration: const InputDecoration(
        labelText: 'Buscar no histórico',
        prefixIcon: Icon(Icons.search),
      ),
    );
    final filterButton = SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onOpenFilters,
        icon: const Icon(Icons.filter_alt_outlined),
        label: Text(
          activeFilterCount == 0 ? 'Filtros' : 'Filtros ($activeFilterCount)',
        ),
      ),
    );
    final sortField = DropdownButtonFormField<_MovementSort>(
      value: sort,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Ordenar por'),
      items: [
        for (final option in _MovementSort.values)
          DropdownMenuItem(
            value: option,
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) onSortChanged(value);
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              filterButton,
              const SizedBox(height: 12),
              sortField,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            SizedBox(width: 150, child: filterButton),
            const SizedBox(width: 12),
            SizedBox(width: 270, child: sortField),
          ],
        );
      },
    );
  }
}

class _ActiveMovementFilters extends StatelessWidget {
  const _ActiveMovementFilters({
    required this.filters,
    required this.productsById,
    required this.onChanged,
  });

  final _MovementFilters filters;
  final Map<String, Product> productsById;
  final ValueChanged<_MovementFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (filters.operation != _MovementFilter.all)
          InputChip(
            label: Text('Operação: ${filters.operation.label}'),
            onDeleted: () =>
                onChanged(filters.copyWith(operation: _MovementFilter.all)),
          ),
        if (filters.type != null)
          InputChip(
            label: Text('Motivo: ${filters.type!.label}'),
            onDeleted: () => onChanged(filters.copyWith(clearType: true)),
          ),
        if (filters.period != _MovementPeriod.all)
          InputChip(
            label: Text(_movementPeriodFilterLabel(filters)),
            onDeleted: () => onChanged(
              filters.copyWith(
                period: _MovementPeriod.all,
                clearCustomPeriod: true,
              ),
            ),
          ),
        if (filters.productIds.isNotEmpty)
          InputChip(
            label: Text(_selectedProductsFilterLabel(filters, productsById)),
            onDeleted: () =>
                onChanged(filters.copyWith(productIds: const <String>{})),
          ),
        if (filters.minimumProducts != null || filters.maximumProducts != null)
          InputChip(
            label: Text(_productCountFilterLabel(filters)),
            onDeleted: () =>
                onChanged(filters.copyWith(clearProductRange: true)),
          ),
        if (filters.observation != _MovementObservationFilter.all)
          InputChip(
            label: Text(filters.observation.label),
            onDeleted: () => onChanged(
              filters.copyWith(observation: _MovementObservationFilter.all),
            ),
          ),
        TextButton.icon(
          onPressed: () => onChanged(const _MovementFilters()),
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Limpar filtros'),
        ),
      ],
    );
  }
}

class _AdvancedMovementFiltersDialog extends StatefulWidget {
  const _AdvancedMovementFiltersDialog({
    required this.initialFilters,
    required this.products,
  });

  final _MovementFilters initialFilters;
  final List<Product> products;

  @override
  State<_AdvancedMovementFiltersDialog> createState() =>
      _AdvancedMovementFiltersDialogState();
}

class _AdvancedMovementFiltersDialogState
    extends State<_AdvancedMovementFiltersDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minimumProductsController;
  late final TextEditingController _maximumProductsController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late _MovementFilter _operation;
  late StockMovementType? _type;
  late _MovementPeriod _period;
  late Set<String> _productIds;
  late _MovementObservationFilter _observation;
  String? _periodError;
  String? _productRangeError;

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters;
    _operation = filters.operation;
    _type = filters.type;
    _period = filters.period;
    _productIds = {...filters.productIds};
    _observation = filters.observation;
    _startDateController = TextEditingController(
      text: filters.customPeriod == null
          ? ''
          : _movementDayFormat.format(filters.customPeriod!.start),
    );
    _endDateController = TextEditingController(
      text: filters.customPeriod == null
          ? ''
          : _movementDayFormat.format(filters.customPeriod!.end),
    );
    _minimumProductsController = TextEditingController(
      text: filters.minimumProducts?.toString() ?? '',
    );
    _maximumProductsController = TextEditingController(
      text: filters.maximumProducts?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minimumProductsController.dispose();
    _maximumProductsController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableTypes = _movementTypesForFilter(_operation);

    return AlertDialog(
      icon: const Icon(Icons.filter_alt_outlined),
      title: const Text('Filtros avançados'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<_MovementFilter>(
                  value: _operation,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Operação'),
                  items: [
                    for (final option in _MovementFilter.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _operation = value;
                      if (_type != null &&
                          !_movementTypesForFilter(value).contains(_type)) {
                        _type = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _type?.code ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da movimentação',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Todos'),
                    ),
                    for (final type in availableTypes)
                      DropdownMenuItem<String>(
                        value: type.code,
                        child: Text(type.label),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _type = value == null || value.isEmpty
                        ? null
                        : stockMovementTypeFromCode(value);
                  }),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<_MovementPeriod>(
                  value: _period,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Período'),
                  items: [
                    for (final option in _MovementPeriod.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _period = value;
                      _periodError = null;
                    });
                  },
                ),
                if (_period == _MovementPeriod.custom) ...[
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final startField = TextFormField(
                        controller: _startDateController,
                        keyboardType: TextInputType.datetime,
                        textInputAction: TextInputAction.next,
                        inputFormatters: const [_MovementDateInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Início',
                          hintText: 'dd/mm/aaaa',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: _movementDateValidator,
                        onChanged: (_) {
                          if (_periodError != null) {
                            setState(() => _periodError = null);
                          }
                        },
                      );
                      final endField = TextFormField(
                        controller: _endDateController,
                        keyboardType: TextInputType.datetime,
                        inputFormatters: const [_MovementDateInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Fim',
                          hintText: 'dd/mm/aaaa',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        validator: _movementDateValidator,
                        onChanged: (_) {
                          if (_periodError != null) {
                            setState(() => _periodError = null);
                          }
                        },
                      );

                      if (constraints.maxWidth < 400) {
                        return Column(
                          children: [
                            startField,
                            const SizedBox(height: 12),
                            endField,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: startField),
                          const SizedBox(width: 12),
                          Expanded(child: endField),
                        ],
                      );
                    },
                  ),
                  if (_periodError != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      _periodError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _selectProducts,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(
                      _productIds.isEmpty
                          ? 'Produtos: todos'
                          : 'Produtos selecionados: ${_productIds.length}',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Quantidade de produtos na operação',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final minimumField = TextFormField(
                      controller: _minimumProductsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Mínimo'),
                      validator: _positiveIntegerValidator,
                    );
                    final maximumField = TextFormField(
                      controller: _maximumProductsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Máximo'),
                      validator: _positiveIntegerValidator,
                    );

                    if (constraints.maxWidth < 400) {
                      return Column(
                        children: [
                          minimumField,
                          const SizedBox(height: 12),
                          maximumField,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: minimumField),
                        const SizedBox(width: 12),
                        Expanded(child: maximumField),
                      ],
                    );
                  },
                ),
                if (_productRangeError != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    _productRangeError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<_MovementObservationFilter>(
                  value: _observation,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Observação'),
                  items: [
                    for (final option in _MovementObservationFilter.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _observation = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _clear,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Limpar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _apply,
          icon: const Icon(Icons.check),
          label: const Text('Aplicar filtros'),
        ),
      ],
    );
  }

  Future<void> _selectProducts() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _MovementProductFilterDialog(
        products: widget.products,
        initialProductIds: _productIds,
      ),
    );
    if (result != null && mounted) {
      setState(() => _productIds = result);
    }
  }

  void _clear() {
    setState(() {
      _operation = _MovementFilter.all;
      _type = null;
      _period = _MovementPeriod.all;
      _startDateController.clear();
      _endDateController.clear();
      _productIds = <String>{};
      _minimumProductsController.clear();
      _maximumProductsController.clear();
      _observation = _MovementObservationFilter.all;
      _periodError = null;
      _productRangeError = null;
    });
  }

  void _apply() {
    FocusScope.of(context).unfocus();
    final formIsValid = _formKey.currentState!.validate();
    final minimum = int.tryParse(_minimumProductsController.text);
    final maximum = int.tryParse(_maximumProductsController.text);
    final startDate = _parseMovementDate(_startDateController.text);
    final endDate = _parseMovementDate(_endDateController.text);
    final periodIsValid =
        _period != _MovementPeriod.custom ||
        (startDate != null && endDate != null);
    final dateRangeIsValid =
        !periodIsValid ||
        _period != _MovementPeriod.custom ||
        !startDate!.isAfter(endDate!);
    final rangeIsValid =
        minimum == null || maximum == null || minimum <= maximum;

    setState(() {
      _periodError = dateRangeIsValid
          ? null
          : 'A data inicial não pode ser posterior à data final.';
      _productRangeError = rangeIsValid
          ? null
          : 'O mínimo não pode ser maior que o máximo.';
    });
    if (!formIsValid || !periodIsValid || !dateRangeIsValid || !rangeIsValid) {
      return;
    }

    Navigator.of(context).pop(
      _MovementFilters(
        operation: _operation,
        type: _type,
        period: _period,
        customPeriod: _period == _MovementPeriod.custom
            ? DateTimeRange(start: startDate!, end: endDate!)
            : null,
        productIds: Set.unmodifiable(_productIds),
        minimumProducts: minimum,
        maximumProducts: maximum,
        observation: _observation,
      ),
    );
  }
}

class _MovementProductFilterDialog extends StatefulWidget {
  const _MovementProductFilterDialog({
    required this.products,
    required this.initialProductIds,
  });

  final List<Product> products;
  final Set<String> initialProductIds;

  @override
  State<_MovementProductFilterDialog> createState() =>
      _MovementProductFilterDialogState();
}

class _MovementProductFilterDialogState
    extends State<_MovementProductFilterDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<String> _selectedIds;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = {...widget.initialProductIds};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedSearch = _search.trim().toLowerCase();
    final visibleProducts =
        widget.products.where((product) {
          return normalizedSearch.isEmpty ||
              product.name.toLowerCase().contains(normalizedSearch) ||
              product.description.toLowerCase().contains(normalizedSearch) ||
              product.supplier.toLowerCase().contains(normalizedSearch);
        }).toList()..sort(
          (first, second) => _compareNaturalText(first.name, second.name),
        );

    return AlertDialog(
      icon: const Icon(Icons.inventory_2_outlined),
      title: const Text('Filtrar por produtos'),
      content: SizedBox(
        width: 520,
        height: MediaQuery.sizeOf(context).height * 0.58,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                labelText: 'Buscar produtos',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Todos os produtos'
                        : '${_selectedIds.length} selecionado(s)',
                  ),
                ),
                TextButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => setState(_selectedIds.clear),
                  child: const Text('Limpar'),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: visibleProducts.isEmpty
                  ? const Center(child: Text('Nenhum produto encontrado.'))
                  : ListView.builder(
                      itemCount: visibleProducts.length,
                      itemBuilder: (context, index) {
                        final product = visibleProducts[index];
                        final selected = _selectedIds.contains(product.id);
                        return CheckboxListTile(
                          value: selected,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: product.description.trim().isEmpty
                              ? null
                              : Text(
                                  product.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              _selectedIds.add(product.id);
                            } else {
                              _selectedIds.remove(product.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(Set<String>.unmodifiable(_selectedIds)),
          icon: const Icon(Icons.check),
          label: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _MovementHistory extends StatelessWidget {
  const _MovementHistory({
    required this.operations,
    required this.productsById,
  });

  final List<_StockOperation> operations;
  final Map<String, Product> productsById;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (final operation in operations) ...[
                _OperationCard(
                  operation: operation,
                  productsById: productsById,
                ),
                if (operation != operations.last) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return _MovementTable(
          operations: operations,
          productsById: productsById,
        );
      },
    );
  }
}

class _MovementTable extends StatefulWidget {
  const _MovementTable({required this.operations, required this.productsById});

  final List<_StockOperation> operations;
  final Map<String, Product> productsById;

  @override
  State<_MovementTable> createState() => _MovementTableState();
}

class _MovementTableState extends State<_MovementTable> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedOperationIds = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Container(
          width: 1180,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const _MovementTableHeader(),
              for (final operation in widget.operations) ...[
                _OperationTableRow(
                  operation: operation,
                  productsById: widget.productsById,
                  expanded: _expandedOperationIds.contains(operation.id),
                  onToggle: () => setState(() {
                    if (!_expandedOperationIds.add(operation.id)) {
                      _expandedOperationIds.remove(operation.id);
                    }
                  }),
                ),
                if (_expandedOperationIds.contains(operation.id))
                  _OperationItems(
                    operation: operation,
                    productsById: widget.productsById,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementTableHeader extends StatelessWidget {
  const _MovementTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: const Row(
        children: [
          _TableCell(width: 170, child: Text('Data e hora')),
          _TableCell(width: 160, child: Text('Operação')),
          _TableCell(width: 320, child: Text('Produtos')),
          _TableCell(width: 110, child: Text('Itens')),
          Expanded(child: Text('Detalhes')),
          SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _OperationTableRow extends StatelessWidget {
  const _OperationTableRow({
    required this.operation,
    required this.productsById,
    required this.expanded,
    required this.onToggle,
  });

  final _StockOperation operation;
  final Map<String, Product> productsById;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detail = _operationDetail(operation);

    return Material(
      color: expanded
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerLowest,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              _TableCell(
                width: 170,
                child: Text(_movementDateFormat.format(operation.occurredAt)),
              ),
              _TableCell(
                width: 160,
                child: _MovementBadge(movement: operation.reference),
              ),
              _TableCell(
                width: 320,
                child: Text(
                  _operationProductSummary(operation, productsById),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _TableCell(
                width: 110,
                child: Text(_operationItemCount(operation)),
              ),
              Expanded(
                child: Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              SizedBox(
                width: 44,
                child: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _OperationItems extends StatelessWidget {
  const _OperationItems({required this.operation, required this.productsById});

  final _StockOperation operation;
  final Map<String, Product> productsById;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produtos da operação',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _TableCell(width: 390, child: Text('Produto')),
              _TableCell(width: 170, child: Text('Quantidade')),
              _TableCell(width: 190, child: Text('Saldo anterior')),
              Expanded(child: Text('Saldo após')),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: colorScheme.outlineVariant),
          for (final movement in operation.items) ...[
            _OperationItemRow(
              movement: movement,
              product: productsById[movement.productId],
            ),
            if (movement != operation.items.last)
              Divider(color: colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _OperationItemRow extends StatelessWidget {
  const _OperationItemRow({required this.movement, required this.product});

  final StockMovement movement;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final unit = product?.unit ?? 'un';
    final previousStock = movement.stockAfter == null
        ? null
        : movement.stockAfter! - movement.quantityDelta;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _TableCell(
            width: 390,
            child: Text(
              product?.name ?? 'Produto removido',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          _TableCell(
            width: 170,
            child: Text(
              _signedQuantity(movement.quantityDelta, unit),
              style: TextStyle(
                color: _movementColor(context, movement),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _TableCell(
            width: 190,
            child: Text(
              previousStock == null ? 'Não informado' : '$previousStock $unit',
            ),
          ),
          Expanded(
            child: Text(
              movement.stockAfter == null
                  ? 'Não informado'
                  : '${movement.stockAfter} $unit',
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationCard extends StatefulWidget {
  const _OperationCard({required this.operation, required this.productsById});

  final _StockOperation operation;
  final Map<String, Product> productsById;

  @override
  State<_OperationCard> createState() => _OperationCardState();
}

class _OperationCardState extends State<_OperationCard> {
  bool _expanded = false;

  _StockOperation get operation => widget.operation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _operationProductSummary(
                            operation,
                            widget.productsById,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _movementDateFormat.format(operation.occurredAt),
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _MovementBadge(movement: operation.reference),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MovementDetail(
                      label: 'Itens',
                      value: _operationItemCount(operation),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_operationDetail(operation) != 'Sem detalhes') ...[
                const SizedBox(height: 14),
                Text(
                  _operationDetail(operation),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
              if (_expanded) ...[
                const SizedBox(height: 14),
                Divider(color: colorScheme.outlineVariant),
                const SizedBox(height: 6),
                for (final movement in operation.items) ...[
                  _OperationCardItem(
                    movement: movement,
                    product: widget.productsById[movement.productId],
                  ),
                  if (movement != operation.items.last)
                    const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationCardItem extends StatelessWidget {
  const _OperationCardItem({required this.movement, required this.product});

  final StockMovement movement;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = product?.unit ?? 'un';
    final previousStock = movement.stockAfter == null
        ? null
        : movement.stockAfter! - movement.quantityDelta;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product?.name ?? 'Produto removido',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _MovementDetail(
                label: 'Quantidade',
                value: _signedQuantity(movement.quantityDelta, unit),
                valueColor: _movementColor(context, movement),
              ),
              _MovementDetail(
                label: 'Saldo anterior',
                value: previousStock == null
                    ? 'Não informado'
                    : '$previousStock $unit',
              ),
              _MovementDetail(
                label: 'Saldo após',
                value: movement.stockAfter == null
                    ? 'Não informado'
                    : '${movement.stockAfter} $unit',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovementDetail extends StatelessWidget {
  const _MovementDetail({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}

class _MovementBadge extends StatelessWidget {
  const _MovementBadge({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final color = _movementColor(context, movement);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_movementIcon(movement), color: color, size: 18),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            movement.type.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _StockPagination extends StatelessWidget {
  const _StockPagination({
    required this.currentPage,
    required this.pageCount,
    required this.operationCount,
    required this.onPageChanged,
  });

  final int currentPage;
  final int pageCount;
  final int operationCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final label = operationCount == 1 ? 'operação' : 'operações';
    final pageText =
        'Página $currentPage de $pageCount • $operationCount $label';
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    if (pageCount <= 1) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(pageText, style: style),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Página anterior',
              onPressed: currentPage == 1
                  ? null
                  : () => onPageChanged(currentPage - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            for (var page = 1; page <= pageCount; page++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: page == currentPage
                    ? FilledButton(
                        onPressed: () => onPageChanged(page),
                        child: Text('$page'),
                      )
                    : TextButton(
                        onPressed: () => onPageChanged(page),
                        child: Text('$page'),
                      ),
              ),
            IconButton(
              tooltip: 'Próxima página',
              onPressed: currentPage == pageCount
                  ? null
                  : () => onPageChanged(currentPage + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        );

        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(pageText, style: style),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: controls,
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(pageText, style: style),
            controls,
          ],
        );
      },
    );
  }
}

class _StockEmptyState extends StatelessWidget {
  const _StockEmptyState({required this.onRegisterMovement});

  final VoidCallback onRegisterMovement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.aqua.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sync_alt_outlined,
              color: AppTheme.aqua,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sem movimentações registradas',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Registre a primeira entrada, saída ou correção de saldo.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRegisterMovement,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Registrar movimento'),
          ),
        ],
      ),
    );
  }
}

class _StockMessage extends StatelessWidget {
  const _StockMessage({
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

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StockLoading extends StatelessWidget {
  const _StockLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

enum _MovementDirection { inbound, outbound, adjustment }

enum _AdjustmentDirection { increase, decrease }

class _MovementFormDialog extends StatefulWidget {
  const _MovementFormDialog({
    required this.companyId,
    required this.userId,
    required this.products,
    required this.inventoryService,
  });

  final String companyId;
  final String userId;
  final List<Product> products;
  final InventoryService inventoryService;

  @override
  State<_MovementFormDialog> createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends State<_MovementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  late final List<Product> _products;
  final List<_MovementFormItem> _items = [];
  _MovementDirection _direction = _MovementDirection.inbound;
  _AdjustmentDirection _adjustmentDirection = _AdjustmentDirection.increase;
  StockMovementType _type = StockMovementType.inbound;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _products = [...widget.products]
      ..sort((first, second) => _compareNaturalText(first.name, second.name));
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose(_refreshPreview);
    }
    _reasonController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 640;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: EdgeInsets.all(isCompact ? 12 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height - (isCompact ? 24 : 48),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Registrar movimentação',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operação',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_MovementDirection>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _MovementDirection.inbound,
                              icon: Icon(Icons.add_circle_outline),
                              label: Text('Entrada'),
                            ),
                            ButtonSegment(
                              value: _MovementDirection.outbound,
                              icon: Icon(Icons.remove_circle_outline),
                              label: Text('Saída'),
                            ),
                            ButtonSegment(
                              value: _MovementDirection.adjustment,
                              icon: Icon(Icons.tune_outlined),
                              label: Text('Ajuste'),
                            ),
                          ],
                          selected: {_direction},
                          onSelectionChanged: _saving
                              ? null
                              : (selection) => _setDirection(selection.first),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_direction != _MovementDirection.adjustment)
                        DropdownButtonFormField<StockMovementType>(
                          value: _type,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Motivo da movimentação',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: [
                            for (final type in _availableTypes)
                              DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _type = value);
                                  }
                                },
                        )
                      else ...[
                        Text(
                          'Tipo de ajuste',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<_AdjustmentDirection>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: _AdjustmentDirection.increase,
                                icon: Icon(Icons.add),
                                label: Text('Aumentar saldo'),
                              ),
                              ButtonSegment(
                                value: _AdjustmentDirection.decrease,
                                icon: Icon(Icons.remove),
                                label: Text('Reduzir saldo'),
                              ),
                            ],
                            selected: {_adjustmentDirection},
                            onSelectionChanged: _saving
                                ? null
                                : (selection) => setState(
                                    () =>
                                        _adjustmentDirection = selection.first,
                                  ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _MovementItemsEditor(
                        items: _items,
                        enabled: !_saving,
                        quantityDelta: _quantityDelta,
                        onAdd: _addProduct,
                        onRemove: _removeProduct,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _reasonController,
                        enabled: !_saving,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 240,
                        decoration: const InputDecoration(
                          labelText: 'Observação (opcional)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving || _items.isEmpty ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _items.length <= 1
                          ? 'Registrar'
                          : 'Registrar ${_items.length} itens',
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

  List<StockMovementType> get _availableTypes {
    return switch (_direction) {
      _MovementDirection.inbound => [
        StockMovementType.inbound,
        StockMovementType.returnItem,
      ],
      _MovementDirection.outbound => [
        StockMovementType.sale,
        StockMovementType.loss,
        StockMovementType.damage,
        StockMovementType.ownUse,
        StockMovementType.gift,
        StockMovementType.other,
      ],
      _MovementDirection.adjustment => [StockMovementType.adjustment],
    };
  }

  int _quantityDelta(int quantity) {
    return switch (_direction) {
      _MovementDirection.inbound => quantity,
      _MovementDirection.outbound => -quantity,
      _MovementDirection.adjustment =>
        _adjustmentDirection == _AdjustmentDirection.increase
            ? quantity
            : -quantity,
    };
  }

  Future<void> _addProduct() async {
    final selectedIds = _items.map((item) => item.product.id).toSet();
    final availableProducts = _products
        .where((product) => !selectedIds.contains(product.id))
        .toList(growable: false);

    if (availableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os produtos ativos já foram adicionados.'),
        ),
      );
      return;
    }

    final product = await showDialog<Product>(
      context: context,
      builder: (context) => _ProductSearchDialog(products: availableProducts),
    );
    if (product == null || !mounted) return;

    final item = _MovementFormItem(product);
    item.quantityController.addListener(_refreshPreview);
    setState(() {
      _items.add(item);
      _errorMessage = null;
    });
  }

  void _removeProduct(_MovementFormItem item) {
    item.dispose(_refreshPreview);
    setState(() {
      _items.remove(item);
      _errorMessage = null;
    });
  }

  void _setDirection(_MovementDirection direction) {
    setState(() {
      _direction = direction;
      _type = switch (direction) {
        _MovementDirection.inbound => StockMovementType.inbound,
        _MovementDirection.outbound => StockMovementType.sale,
        _MovementDirection.adjustment => StockMovementType.adjustment,
      };
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_items.isEmpty) {
      setState(() => _errorMessage = 'Adicione pelo menos um produto.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.inventoryService.applyMovements(
        companyId: widget.companyId,
        items: [
          for (final item in _items)
            StockMovementRequest(
              productId: item.product.id,
              quantityDelta: _quantityDelta(item.quantity),
            ),
        ],
        type: _type,
        userId: widget.userId,
        reason: _reasonController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _stockErrorMessage(error);
        });
      }
    }
  }
}

class _MovementFormItem {
  _MovementFormItem(this.product);

  final Product product;
  final TextEditingController quantityController = TextEditingController();

  int get quantity => int.tryParse(quantityController.text) ?? 0;

  void dispose(VoidCallback listener) {
    quantityController
      ..removeListener(listener)
      ..dispose();
  }
}

class _MovementItemsEditor extends StatelessWidget {
  const _MovementItemsEditor({
    required this.items,
    required this.enabled,
    required this.quantityDelta,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_MovementFormItem> items;
  final bool enabled;
  final int Function(int quantity) quantityDelta;
  final VoidCallback onAdd;
  final ValueChanged<_MovementFormItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                items.isEmpty ? 'Produtos' : 'Produtos (${items.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar produto'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.playlist_add_outlined,
                  size: 34,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nenhum produto adicionado',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  'Use a busca para adicionar um ou mais produtos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else
          for (final item in items) ...[
            _MovementItemTile(
              item: item,
              enabled: enabled,
              quantityDelta: quantityDelta,
              onRemove: () => onRemove(item),
            ),
            if (item != items.last) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _MovementItemTile extends StatelessWidget {
  const _MovementItemTile({
    required this.item,
    required this.enabled,
    required this.quantityDelta,
    required this.onRemove,
  });

  final _MovementFormItem item;
  final bool enabled;
  final int Function(int quantity) quantityDelta;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final product = item.product;
    final nextStock = product.currentStock + quantityDelta(item.quantity);
    final invalidStock = nextStock < 0;
    final quantityField = TextFormField(
      controller: item.quantityController,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Quantidade',
        prefixIcon: const Icon(Icons.numbers),
        suffixText: product.unit,
      ),
      validator: (value) {
        final quantity = int.tryParse(value ?? '');
        if (quantity == null || quantity <= 0) {
          return 'Informe uma quantidade maior que zero.';
        }
        if (product.currentStock + quantityDelta(quantity) < 0) {
          return 'Ultrapassa o estoque disponível.';
        }
        return null;
      },
    );
    final balancePreview = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Saldo atual: ${product.currentStock} ${product.unit}',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Novo saldo: $nextStock ${product.unit}',
            style: TextStyle(
              color: invalidStock ? colorScheme.error : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: invalidStock ? colorScheme.error : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Remover produto',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    quantityField,
                    const SizedBox(height: 10),
                    balancePreview,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 190, child: quantityField),
                  const SizedBox(width: 12),
                  Expanded(child: balancePreview),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProductSearchDialog extends StatefulWidget {
  const _ProductSearchDialog({required this.products});

  final List<Product> products;

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedSearch = _search.trim().toLowerCase();
    final products = widget.products
        .where((product) {
          return normalizedSearch.isEmpty ||
              product.name.toLowerCase().contains(normalizedSearch) ||
              product.description.toLowerCase().contains(normalizedSearch) ||
              product.supplier.toLowerCase().contains(normalizedSearch);
        })
        .toList(growable: false);
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height - 36,
        ),
        child: SizedBox(
          height: 590,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Adicionar produto',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    labelText: 'Buscar produto',
                    hintText: 'Nome, descrição ou fornecedor',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_outlined,
                                size: 36,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 10),
                              const Text('Nenhum produto encontrado'),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: products.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(product.name),
                            subtitle: Text(
                              'Saldo: ${product.currentStock} ${product.unit}'
                              '${product.supplier.isEmpty ? '' : ' • ${product.supplier}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () => Navigator.of(context).pop(product),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final RegExp _stockNaturalSortPartPattern = RegExp(r'\d+|\D+');

int _compareNaturalText(String first, String second) {
  final normalizedFirst = first.toLowerCase();
  final normalizedSecond = second.toLowerCase();
  final firstParts = _stockNaturalSortPartPattern
      .allMatches(normalizedFirst)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final secondParts = _stockNaturalSortPartPattern
      .allMatches(normalizedSecond)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final commonLength = firstParts.length < secondParts.length
      ? firstParts.length
      : secondParts.length;

  for (var index = 0; index < commonLength; index++) {
    final firstPart = firstParts[index];
    final secondPart = secondParts[index];
    final firstNumber = BigInt.tryParse(firstPart);
    final secondNumber = BigInt.tryParse(secondPart);
    final comparison = firstNumber != null && secondNumber != null
        ? firstNumber.compareTo(secondNumber)
        : firstPart.compareTo(secondPart);
    if (comparison != 0) return comparison;
  }

  final partCountComparison = firstParts.length.compareTo(secondParts.length);
  if (partCountComparison != 0) return partCountComparison;
  return normalizedFirst.compareTo(normalizedSecond);
}

final DateFormat _movementDateFormat = DateFormat('dd/MM/yyyy HH:mm');
final DateFormat _movementDayFormat = DateFormat('dd/MM/yyyy');

class _MovementDateInputFormatter extends TextInputFormatter {
  const _MovementDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final text = switch (limited.length) {
      <= 2 => limited,
      <= 4 => '${limited.substring(0, 2)}/${limited.substring(2)}',
      _ =>
        '${limited.substring(0, 2)}/${limited.substring(2, 4)}/${limited.substring(4)}',
    };

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

DateTime? _parseMovementDate(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return null;

  final day = int.tryParse(digits.substring(0, 2));
  final month = int.tryParse(digits.substring(2, 4));
  final year = int.tryParse(digits.substring(4, 8));
  if (day == null || month == null || year == null || year < 1900) {
    return null;
  }

  final date = DateTime(year, month, day);
  if (date.day != day || date.month != month || date.year != year) {
    return null;
  }
  return date;
}

String? _movementDateValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Informe a data.';
  if (_parseMovementDate(text) == null) return 'Informe uma data válida.';
  return null;
}

bool _matchesOperationFilter(
  _StockOperation operation,
  _MovementFilter filter,
) {
  return switch (filter) {
    _MovementFilter.all => true,
    _MovementFilter.inbound =>
      operation.type != StockMovementType.adjustment &&
          operation.increasesStock,
    _MovementFilter.outbound =>
      operation.type != StockMovementType.adjustment &&
          operation.decreasesStock,
    _MovementFilter.adjustments =>
      operation.type == StockMovementType.adjustment,
  };
}

bool _matchesMovementPeriod(DateTime occurredAt, _MovementFilters filters) {
  final range = _resolvedMovementPeriod(filters);
  if (range == null) return true;

  final localDate = occurredAt.toLocal();
  final day = DateTime(localDate.year, localDate.month, localDate.day);
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  return !day.isBefore(start) && !day.isAfter(end);
}

DateTimeRange? _resolvedMovementPeriod(_MovementFilters filters) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return switch (filters.period) {
    _MovementPeriod.all => null,
    _MovementPeriod.today => DateTimeRange(start: today, end: today),
    _MovementPeriod.last7Days => DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    ),
    _MovementPeriod.last30Days => DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    ),
    _MovementPeriod.custom => filters.customPeriod,
  };
}

int _compareStockOperations(
  _StockOperation first,
  _StockOperation second,
  _MovementSort sort,
) {
  final comparison = switch (sort) {
    _MovementSort.newestFirst => second.occurredAt.compareTo(first.occurredAt),
    _MovementSort.oldestFirst => first.occurredAt.compareTo(second.occurredAt),
    _MovementSort.mostProductsFirst => second.items.length.compareTo(
      first.items.length,
    ),
    _MovementSort.fewestProductsFirst => first.items.length.compareTo(
      second.items.length,
    ),
    _MovementSort.inboundFirst => _operationSortGroup(
      first,
      inboundFirst: true,
    ).compareTo(_operationSortGroup(second, inboundFirst: true)),
    _MovementSort.outboundFirst => _operationSortGroup(
      first,
      inboundFirst: false,
    ).compareTo(_operationSortGroup(second, inboundFirst: false)),
  };
  if (comparison != 0) return comparison;

  final dateComparison = second.occurredAt.compareTo(first.occurredAt);
  if (dateComparison != 0) return dateComparison;
  return first.id.compareTo(second.id);
}

int _operationSortGroup(
  _StockOperation operation, {
  required bool inboundFirst,
}) {
  if (operation.type == StockMovementType.adjustment) return 1;
  if (operation.increasesStock) return inboundFirst ? 0 : 2;
  return inboundFirst ? 2 : 0;
}

List<StockMovementType> _movementTypesForFilter(_MovementFilter filter) {
  return switch (filter) {
    _MovementFilter.all => StockMovementType.values,
    _MovementFilter.inbound => const [
      StockMovementType.inbound,
      StockMovementType.returnItem,
    ],
    _MovementFilter.outbound => const [
      StockMovementType.sale,
      StockMovementType.loss,
      StockMovementType.damage,
      StockMovementType.ownUse,
      StockMovementType.gift,
      StockMovementType.other,
    ],
    _MovementFilter.adjustments => const [StockMovementType.adjustment],
  };
}

String? _positiveIntegerValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final number = int.tryParse(text);
  if (number == null || number < 1) {
    return 'Informe um número maior que zero.';
  }
  return null;
}

String _movementPeriodFilterLabel(_MovementFilters filters) {
  if (filters.period == _MovementPeriod.custom &&
      filters.customPeriod != null) {
    return 'Período: ${_formatDateRange(filters.customPeriod!)}';
  }
  return 'Período: ${filters.period.label}';
}

String _formatDateRange(DateTimeRange range) {
  return '${_movementDayFormat.format(range.start)} a '
      '${_movementDayFormat.format(range.end)}';
}

String _selectedProductsFilterLabel(
  _MovementFilters filters,
  Map<String, Product> productsById,
) {
  if (filters.productIds.length == 1) {
    final productId = filters.productIds.first;
    return 'Produto: ${productsById[productId]?.name ?? 'indisponível'}';
  }
  return 'Produtos: ${filters.productIds.length} selecionados';
}

String _productCountFilterLabel(_MovementFilters filters) {
  final minimum = filters.minimumProducts;
  final maximum = filters.maximumProducts;
  if (minimum != null && maximum != null) {
    return 'Produtos por operação: $minimum a $maximum';
  }
  if (minimum != null) {
    return 'Produtos por operação: a partir de $minimum';
  }
  return 'Produtos por operação: até $maximum';
}

String _signedQuantity(int quantity, String unit) {
  final prefix = quantity > 0 ? '+' : '';
  return '$prefix$quantity $unit';
}

String _operationDetail(_StockOperation operation) {
  final parts = [
    if (operation.reason.trim().isNotEmpty) operation.reason.trim(),
    if (operation.note.trim().isNotEmpty) operation.note.trim(),
  ];
  return parts.isEmpty ? 'Sem detalhes' : parts.join(' - ');
}

String _operationItemCount(_StockOperation operation) {
  final count = operation.items.length;
  return count == 1 ? '1 produto' : '$count produtos';
}

String _operationProductSummary(
  _StockOperation operation,
  Map<String, Product> productsById,
) {
  final names = [
    for (final movement in operation.items)
      productsById[movement.productId]?.name ?? 'Produto removido',
  ];
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')} e mais ${names.length - 2}';
}

Color _movementColor(BuildContext context, StockMovement movement) {
  if (movement.type == StockMovementType.adjustment) return AppTheme.aqua;
  if (movement.increasesStock) return AppTheme.success;
  return Theme.of(context).colorScheme.error;
}

IconData _movementIcon(StockMovement movement) {
  if (movement.type == StockMovementType.adjustment) {
    return Icons.tune_outlined;
  }
  return movement.increasesStock ? Icons.arrow_upward : Icons.arrow_downward;
}

String _stockErrorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'O Firebase bloqueou esta movimentação. Confira as permissões.',
      'unavailable' =>
        'O serviço está indisponível no momento. Tente novamente.',
      _ => 'Não foi possível registrar a movimentação. Tente novamente.',
    };
  }

  final message = error.toString().replaceFirst('Bad state: ', '');
  if (message.contains('estoque negativo')) {
    return 'A quantidade informada deixaria o estoque negativo.';
  }
  if (message.contains('Produto não encontrado')) {
    return 'Este produto não está mais disponível.';
  }
  return 'Não foi possível registrar a movimentação. Tente novamente.';
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
