import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_theme.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/app_user.dart';
import '../features/company/data/company_repository.dart';
import '../features/inventory/data/product_repository.dart';
import '../features/inventory/domain/product.dart';
import '../shared/widgets/page_container.dart';

final productsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  companyId,
) {
  return ref.watch(productRepositoryProvider).watchProducts(companyId);
});

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  static const routePath = '/products';
  static const routeName = 'products';

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String _search = '';
  _ProductFilter _filter = _ProductFilter.all;
  _ProductSort _sort = _ProductSort.nameAscending;
  int _currentPage = 1;
  final GlobalKey _listKey = GlobalKey();
  String? _localCompanyId;
  bool _preparingCompany = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _PageMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar sua conta',
        description: 'Atualize a página e tente novamente.',
      ),
      data: (user) {
        if (user == null) {
          return const SizedBox.shrink();
        }

        final companyId = _localCompanyId ?? user.activeCompanyId;
        return _buildPage(user, companyId);
      },
    );
  }

  Widget _buildPage(AppUser user, String? companyId) {
    final productsState = companyId == null
        ? const AsyncValue<List<Product>>.data([])
        : ref.watch(productsProvider(companyId));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Produtos',
            subtitle: 'Cadastro, consulta e organização do catálogo',
            trailing: FilledButton.icon(
              onPressed: _preparingCompany
                  ? null
                  : () => _openProductForm(user),
              icon: _preparingCompany
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_box_outlined),
              label: const Text('Novo produto'),
            ),
          ),
          const SizedBox(height: 20),
          productsState.when(
            loading: () => const _ProductsLoading(),
            error: (error, stackTrace) => _PageMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar os produtos',
              description: _firestoreMessage(error),
            ),
            data: (products) => _ProductsContent(
              products: products,
              search: _search,
              filter: _filter,
              sort: _sort,
              currentPage: _currentPage,
              listKey: _listKey,
              onSearchChanged: (value) => setState(() {
                _search = value;
                _currentPage = 1;
              }),
              onFilterChanged: (value) => setState(() {
                _filter = value;
                _currentPage = 1;
              }),
              onSortChanged: (value) => setState(() {
                _sort = value;
                _currentPage = 1;
              }),
              onPageChanged: _changePage,
              onCreate: () => _openProductForm(user),
              onEdit: (product) => _openProductForm(user, product: product),
            ),
          ),
        ],
      ),
    );
  }

  void _changePage(int page) {
    setState(() => _currentPage = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final listContext = _listKey.currentContext;
      if (!mounted || listContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        listContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.05,
      );
    });
  }

  Future<void> _openProductForm(AppUser user, {Product? product}) async {
    final companyId = await _ensureCompany(user);
    if (!mounted || companyId == null) {
      return;
    }

    final result = await showDialog<_ProductFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProductFormDialog(
        companyId: companyId,
        repository: ref.read(productRepositoryProvider),
        authRepository: ref.read(authRepositoryProvider),
        product: product,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (result) {
          _ProductFormResult.saved =>
            product == null
                ? 'Produto cadastrado com sucesso.'
                : 'Produto atualizado com sucesso.',
          _ProductFormResult.deleted => 'Produto excluído com sucesso.',
        }),
      ),
    );
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

      if (mounted) {
        setState(() => _localCompanyId = companyId);
      }
      return companyId;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_firestoreMessage(error))));
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _preparingCompany = false);
      }
    }
  }
}

class _ProductsContent extends StatelessWidget {
  const _ProductsContent({
    required this.products,
    required this.search,
    required this.filter,
    required this.sort,
    required this.currentPage,
    required this.listKey,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onPageChanged,
    required this.onCreate,
    required this.onEdit,
  });

  final List<Product> products;
  final String search;
  final _ProductFilter filter;
  final _ProductSort sort;
  final int currentPage;
  final GlobalKey listKey;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ProductFilter> onFilterChanged;
  final ValueChanged<_ProductSort> onSortChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onCreate;
  final ValueChanged<Product> onEdit;

  @override
  Widget build(BuildContext context) {
    final normalizedSearch = search.trim().toLowerCase();
    final visibleProducts = products.where((product) {
      final matchesSearch =
          normalizedSearch.isEmpty ||
          product.name.toLowerCase().contains(normalizedSearch) ||
          product.description.toLowerCase().contains(normalizedSearch) ||
          product.supplier.toLowerCase().contains(normalizedSearch);
      final matchesFilter = switch (filter) {
        _ProductFilter.all => true,
        _ProductFilter.active => product.isActive,
        _ProductFilter.inactive => !product.isActive,
      };

      return matchesSearch && matchesFilter;
    }).toList()..sort((first, second) => _compareProducts(first, second, sort));
    final pageCount = (visibleProducts.length / _productsPerPage).ceil();
    final safePage = visibleProducts.isEmpty
        ? 1
        : currentPage.clamp(1, pageCount);
    final firstProductIndex = (safePage - 1) * _productsPerPage;
    final pageProducts = visibleProducts
        .skip(firstProductIndex)
        .take(_productsPerPage)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProductStats(products: products),
        const SizedBox(height: 20),
        _ProductToolbar(
          search: search,
          filter: filter,
          sort: sort,
          onSearchChanged: onSearchChanged,
          onFilterChanged: onFilterChanged,
          onSortChanged: onSortChanged,
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          _EmptyProducts(onCreate: onCreate)
        else if (visibleProducts.isEmpty)
          const _PageMessage(
            icon: Icons.search_off_outlined,
            title: 'Nenhum produto encontrado',
            description: 'Ajuste a busca ou o filtro para ver outros produtos.',
          )
        else
          KeyedSubtree(
            key: listKey,
            child: Column(
              children: [
                _ProductList(products: pageProducts, onEdit: onEdit),
                const SizedBox(height: 10),
                _ProductPagination(
                  currentPage: safePage,
                  pageCount: pageCount,
                  onPageChanged: onPageChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProductStats extends StatelessWidget {
  const _ProductStats({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final activeProducts = products
        .where((product) => product.isActive)
        .toList();
    final lowStock = activeProducts
        .where((product) => product.currentStock > 0 && product.isBelowMinimum)
        .length;
    final outOfStock = activeProducts
        .where((product) => product.isOutOfStock)
        .length;
    final stats = [
      _StatData('Ativos', activeProducts.length, Icons.check_circle_outline),
      _StatData('Estoque baixo', lowStock, Icons.warning_amber_outlined),
      _StatData('Sem estoque', outOfStock, Icons.remove_shopping_cart_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 700
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 440
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final stat in stats)
              SizedBox(
                width: itemWidth,
                child: _StatTile(stat: stat),
              ),
          ],
        );
      },
    );
  }
}

class _StatData {
  const _StatData(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final _StatData stat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(stat.icon, color: AppTheme.primaryBlue),
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
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stat.value}',
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

class _ProductToolbar extends StatelessWidget {
  const _ProductToolbar({
    required this.search,
    required this.filter,
    required this.sort,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final String search;
  final _ProductFilter filter;
  final _ProductSort sort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ProductFilter> onFilterChanged;
  final ValueChanged<_ProductSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final searchField = TextFormField(
          initialValue: search,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Buscar produtos',
            prefixIcon: Icon(Icons.search),
          ),
        );
        final filterField = DropdownButtonFormField<_ProductFilter>(
          value: filter,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Status',
            prefixIcon: Icon(Icons.filter_list),
          ),
          items: const [
            DropdownMenuItem(value: _ProductFilter.all, child: Text('Todos')),
            DropdownMenuItem(
              value: _ProductFilter.active,
              child: Text('Ativos'),
            ),
            DropdownMenuItem(
              value: _ProductFilter.inactive,
              child: Text('Inativos'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onFilterChanged(value);
            }
          },
        );
        final sortField = DropdownButtonFormField<_ProductSort>(
          value: sort,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ordenar por'),
          items: const [
            DropdownMenuItem(
              value: _ProductSort.nameAscending,
              child: Text(
                'Nome: A–Z',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _ProductSort.nameDescending,
              child: Text(
                'Nome: Z–A',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _ProductSort.priceAscending,
              child: Text(
                'Preço: menor primeiro',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _ProductSort.priceDescending,
              child: Text(
                'Preço: maior primeiro',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _ProductSort.activeFirst,
              child: Text(
                'Status: ativos primeiro',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _ProductSort.inactiveFirst,
              child: Text(
                'Status: inativos primeiro',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onSortChanged(value);
            }
          },
        );

        if (constraints.maxWidth < 820) {
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              filterField,
              const SizedBox(height: 12),
              sortField,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            SizedBox(width: 170, child: filterField),
            const SizedBox(width: 12),
            SizedBox(width: 250, child: sortField),
          ],
        );
      },
    );
  }
}

enum _ProductFilter { all, active, inactive }

const _productsPerPage = 14;

enum _ProductSort {
  nameAscending,
  nameDescending,
  priceAscending,
  priceDescending,
  activeFirst,
  inactiveFirst,
}

int _compareProducts(Product first, Product second, _ProductSort sort) {
  final nameComparison = first.name.toLowerCase().compareTo(
    second.name.toLowerCase(),
  );

  return switch (sort) {
    _ProductSort.nameAscending => nameComparison,
    _ProductSort.nameDescending => -nameComparison,
    _ProductSort.priceAscending =>
      first.salePrice.compareTo(second.salePrice) == 0
          ? nameComparison
          : first.salePrice.compareTo(second.salePrice),
    _ProductSort.priceDescending =>
      second.salePrice.compareTo(first.salePrice) == 0
          ? nameComparison
          : second.salePrice.compareTo(first.salePrice),
    _ProductSort.activeFirst =>
      first.isActive == second.isActive
          ? nameComparison
          : first.isActive
          ? -1
          : 1,
    _ProductSort.inactiveFirst =>
      first.isActive == second.isActive
          ? nameComparison
          : first.isActive
          ? 1
          : -1,
  };
}

class _ProductList extends StatelessWidget {
  const _ProductList({required this.products, required this.onEdit});

  final List<Product> products;
  final ValueChanged<Product> onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1000) {
          return Column(
            children: [
              for (var index = 0; index < products.length; index++) ...[
                _ProductCard(product: products[index], onEdit: onEdit),
                if (index != products.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return _ProductTable(products: products, onEdit: onEdit);
      },
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({required this.products, required this.onEdit});

  final List<Product> products;
  final ValueChanged<Product> onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const _ProductTableHeader(),
          const Divider(),
          for (var index = 0; index < products.length; index++) ...[
            _ProductTableRow(product: products[index], onEdit: onEdit),
            if (index != products.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _ProductTableHeader extends StatelessWidget {
  const _ProductTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Produto', style: style)),
          Expanded(flex: 2, child: Text('Preço de venda', style: style)),
          Expanded(child: Text('Estoque', style: style)),
          Expanded(child: Text('Unidade', style: style)),
          Expanded(child: Text('Status', style: style)),
          Expanded(flex: 2, child: Text('Valor de aquisição', style: style)),
          Expanded(flex: 2, child: Text('Estoque mínimo', style: style)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _ProductTableRow extends StatelessWidget {
  const _ProductTableRow({required this.product, required this.onEdit});

  final Product product;
  final ValueChanged<Product> onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  product.description.isEmpty
                      ? 'Sem descrição'
                      : product.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(_currency(product.salePrice))),
          Expanded(child: Text('${product.currentStock}')),
          Expanded(child: Text(product.unit)),
          Expanded(child: _StatusBadge(isActive: product.isActive)),
          Expanded(flex: 2, child: Text(_currency(product.acquisitionCost))),
          Expanded(flex: 2, child: Text('${product.minimumStock}')),
          IconButton(
            tooltip: 'Editar produto',
            onPressed: () => onEdit(product),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onEdit});

  final Product product;
  final ValueChanged<Product> onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
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
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar produto',
                  onPressed: () => onEdit(product),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ProductDetail(
                  label: 'Venda',
                  value: _currency(product.salePrice),
                ),
                _ProductDetail(
                  label: 'Estoque',
                  value: '${product.currentStock}',
                ),
                _ProductDetail(label: 'Unidade', value: product.unit),
                _StatusBadge(isActive: product.isActive),
                _ProductDetail(
                  label: 'Aquisição',
                  value: _currency(product.acquisitionCost),
                ),
                _ProductDetail(
                  label: 'Estoque mínimo',
                  value: '${product.minimumStock}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPagination extends StatelessWidget {
  const _ProductPagination({
    required this.currentPage,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pageText = 'Página $currentPage de $pageCount';

    return LayoutBuilder(
      builder: (context, constraints) {
        if (pageCount <= 1) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                pageText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        if (constraints.maxWidth < 620) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Página anterior',
                onPressed: currentPage == 1
                    ? null
                    : () => onPageChanged(currentPage - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(
                child: Text(
                  pageText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                pageText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Página anterior',
              onPressed: currentPage == 1
                  ? null
                  : () => onPageChanged(currentPage - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            for (final page in _paginationItems(pageCount, currentPage))
              if (page == null)
                const SizedBox(width: 34, child: Center(child: Text('…')))
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: page == currentPage
                      ? FilledButton(
                          onPressed: null,
                          style: FilledButton.styleFrom(
                            disabledBackgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            disabledForegroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            minimumSize: const Size.square(38),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text('$page'),
                        )
                      : TextButton(
                          onPressed: () => onPageChanged(page),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.square(38),
                            padding: EdgeInsets.zero,
                          ),
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
      },
    );
  }
}

List<int?> _paginationItems(int pageCount, int currentPage) {
  if (pageCount <= 7) {
    return [for (var page = 1; page <= pageCount; page++) page];
  }

  final pages = <int>{
    1,
    pageCount,
    currentPage - 1,
    currentPage,
    currentPage + 1,
  };
  if (currentPage <= 3) {
    pages.addAll([2, 3, 4]);
  }
  if (currentPage >= pageCount - 2) {
    pages.addAll([pageCount - 3, pageCount - 2, pageCount - 1]);
  }

  final sortedPages =
      pages.where((page) => page >= 1 && page <= pageCount).toList()..sort();
  final items = <int?>[];

  for (var index = 0; index < sortedPages.length; index++) {
    if (index > 0 && sortedPages[index] - sortedPages[index - 1] > 1) {
      items.add(null);
    }
    items.add(sortedPages[index]);
  }

  return items;
}

class _ProductDetail extends StatelessWidget {
  const _ProductDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppTheme.success
        : Theme.of(context).colorScheme.outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 7),
        Flexible(child: Text(isActive ? 'Ativo' : 'Inativo')),
      ],
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _PageMessage(
      icon: Icons.inventory_2_outlined,
      title: 'Sem produtos cadastrados',
      description:
          'Cadastre o primeiro produto para começar a organizar seu catálogo.',
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Cadastrar produto'),
      ),
    );
  }
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 42),
          child: Column(
            children: [
              Icon(icon, size: 42, color: AppTheme.primaryBlue),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductsLoading extends StatelessWidget {
  const _ProductsLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

enum _ProductFormResult { saved, deleted }

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.companyId,
    required this.repository,
    required this.authRepository,
    this.product,
  });

  final String companyId;
  final ProductRepository repository;
  final AuthRepository authRepository;
  final Product? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _acquisitionCostController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _supplierController;
  late String _unit;
  late bool _isActive;
  bool _saving = false;
  String? _errorMessage;

  static const _units = <String, String>{
    'un': 'Unidade (un)',
    'kg': 'Quilograma (kg)',
    'g': 'Grama (g)',
    'l': 'Litro (l)',
    'ml': 'Mililitro (ml)',
    'cx': 'Caixa (cx)',
    'pct': 'Pacote (pct)',
  };

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _acquisitionCostController = TextEditingController(
      text: product == null ? '' : _editableDecimal(product.acquisitionCost),
    );
    _salePriceController = TextEditingController(
      text: product == null ? '' : _editableDecimal(product.salePrice),
    );
    _minimumStockController = TextEditingController(
      text: product == null ? '' : '${product.minimumStock}',
    );
    _supplierController = TextEditingController(text: product?.supplier ?? '');
    _unit = product?.unit ?? 'un';
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _acquisitionCostController.dispose();
    _salePriceController.dispose();
    _minimumStockController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 640;
    final content = Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            _FormHeader(
              title: widget.product == null ? 'Novo produto' : 'Editar produto',
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),
            const Divider(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: _buildFields(),
                ),
              ),
            ),
            const Divider(),
            _FormActions(
              saving: _saving,
              showDelete: widget.product != null,
              onCancel: () => Navigator.of(context).pop(),
              onDelete: _confirmDelete,
              onSave: _save,
            ),
          ],
        ),
      ),
    );

    if (isCompact) {
      return Dialog.fullscreen(child: content);
    }

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: content,
      ),
    );
  }

  Widget _buildFields() {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: colors.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        TextFormField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Nome do produto',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe o nome do produto.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descriptionController,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Descrição (opcional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              TextFormField(
                controller: _acquisitionCostController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_decimalFormatter],
                decoration: const InputDecoration(
                  labelText: 'Custo de aquisição',
                  prefixText: 'R\$ ',
                ),
                validator: _moneyValidator,
              ),
              TextFormField(
                controller: _salePriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_decimalFormatter],
                decoration: const InputDecoration(
                  labelText: 'Preço de venda',
                  prefixText: 'R\$ ',
                ),
                validator: _moneyValidator,
              ),
            ];
            return _responsiveFields(constraints.maxWidth, fields);
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unidade de medida',
                ),
                items: [
                  for (final unit in _units.entries)
                    DropdownMenuItem(value: unit.key, child: Text(unit.value)),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _unit = value);
                        }
                      },
              ),
              TextFormField(
                controller: _minimumStockController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Estoque mínimo'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  if (int.tryParse(value) == null) {
                    return 'Informe uma quantidade válida.';
                  }
                  return null;
                },
              ),
            ];
            return _responsiveFields(constraints.maxWidth, fields);
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _supplierController,
          textCapitalization: TextCapitalization.words,
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: 'Fornecedor (opcional)',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Produto ativo'),
          subtitle: const Text(
            'Produtos inativos ficam fora das operações do estoque.',
          ),
          value: _isActive,
          onChanged: _saving
              ? null
              : (value) => setState(() => _isActive = value),
        ),
      ],
    );
  }

  Widget _responsiveFields(double width, List<Widget> fields) {
    if (width < 520) {
      return Column(
        children: [fields.first, const SizedBox(height: 14), fields.last],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: fields.first),
        const SizedBox(width: 14),
        Expanded(child: fields.last),
      ],
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final current = widget.product;
    final now = DateTime.now();
    final minimumStock = int.tryParse(_minimumStockController.text) ?? 0;
    final product = Product(
      id: current?.id ?? widget.repository.createId(widget.companyId),
      companyId: widget.companyId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryId: current?.categoryId,
      acquisitionCost: _parseDecimal(_acquisitionCostController.text),
      salePrice: _parseDecimal(_salePriceController.text),
      currentStock: current?.currentStock ?? 0,
      minimumStock: minimumStock,
      reorderPoint: minimumStock,
      unit: _unit,
      supplier: _supplierController.text.trim(),
      isActive: _isActive,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
      metadata: current?.metadata ?? const {},
    );

    try {
      await widget.repository.save(product);
      if (mounted) {
        Navigator.of(context).pop(_ProductFormResult.saved);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _firestoreMessage(error);
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final product = widget.product;
    if (product == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _DeleteConfirmationDialog(productName: product.name),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeletePasswordDialog(
        productName: product.name,
        onConfirm: (password) async {
          await widget.authRepository.reauthenticateWithPassword(password);
          await widget.repository.delete(widget.companyId, product.id);
        },
      ),
    );

    if (deleted == true && mounted) {
      Navigator.of(context).pop(_ProductFormResult.deleted);
    }
  }
}

class _DeleteConfirmationDialog extends StatelessWidget {
  const _DeleteConfirmationDialog({required this.productName});

  final String productName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.delete_forever_outlined, color: colors.error),
      title: const Text('Excluir produto?'),
      content: Text(
        'O produto “$productName” será excluído permanentemente. Esta ação não pode ser desfeita.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _DeletePasswordDialog extends StatefulWidget {
  const _DeletePasswordDialog({
    required this.productName,
    required this.onConfirm,
  });

  final String productName;
  final Future<void> Function(String password) onConfirm;

  @override
  State<_DeletePasswordDialog> createState() => _DeletePasswordDialogState();
}

class _DeletePasswordDialogState extends State<_DeletePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        icon: Icon(Icons.lock_outline, color: colors.error),
        title: const Text('Confirme sua senha'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Digite sua senha de acesso para excluir “${widget.productName}”.',
                ),
                const SizedBox(height: 18),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _passwordController,
                  autofocus: true,
                  obscureText: _obscurePassword,
                  enabled: !_submitting,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                      onPressed: _submitting
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe sua senha.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!_submitting) {
                      _submit();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(_submitting ? 'Excluindo...' : 'Excluir produto'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(_passwordController.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = _deleteErrorMessage(error);
        });
      }
    }
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          IconButton(
            tooltip: 'Fechar',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.saving,
    required this.showDelete,
    required this.onCancel,
    required this.onDelete,
    required this.onSave,
  });

  final bool saving;
  final bool showDelete;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final deleteButton = TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: colors.error),
      onPressed: saving ? null : onDelete,
      icon: const Icon(Icons.delete_outline),
      label: const Text('Excluir produto'),
    );
    final saveActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: saving ? null : onCancel,
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'Salvando...' : 'Salvar produto'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.all(16),
        child: constraints.maxWidth < 540 && showDelete
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerLeft, child: deleteButton),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: saveActions),
                ],
              )
            : Row(
                children: [
                  if (showDelete) deleteButton,
                  const Spacer(),
                  saveActions,
                ],
              ),
      ),
    );
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'));

String? _moneyValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  if (_tryParseDecimal(value) == null) {
    return 'Informe um valor válido.';
  }
  return null;
}

double _parseDecimal(String value) => _tryParseDecimal(value) ?? 0;

double? _tryParseDecimal(String value) {
  var normalized = value.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (normalized.isEmpty) {
    return 0;
  }
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(normalized);
}

String _editableDecimal(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String _currency(double value) {
  return NumberFormat.simpleCurrency(locale: 'pt_BR').format(value);
}

String _firestoreMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'O Firebase bloqueou esta operação. Confira as regras do Firestore.';
  }
  if (error is FirebaseException && error.code == 'unavailable') {
    return 'O Firebase está indisponível agora. Tente novamente em instantes.';
  }
  return 'Não foi possível concluir a operação. Tente novamente.';
}

String _deleteErrorMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Senha incorreta. Confira e tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      case 'network-request-failed':
      case 'unavailable':
        return 'Sem conexão com o Firebase. Verifique sua internet e tente novamente.';
      case 'permission-denied':
        return 'Sua conta não tem permissão para excluir este produto.';
      case 'user-disabled':
      case 'user-not-found':
        return 'Não foi possível confirmar a conta atual. Entre novamente no sistema.';
    }
  }

  return 'Não foi possível excluir o produto. Tente novamente.';
}
