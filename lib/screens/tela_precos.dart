import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_theme.dart';
import '../features/auth/application/auth_state.dart';
import '../features/inventory/data/product_repository.dart';
import '../features/inventory/domain/product.dart';
import '../features/pricing/application/pricing_calculator.dart';
import '../features/pricing/domain/pricing_models.dart';
import '../shared/widgets/page_container.dart';

final pricingProductsProvider = StreamProvider<List<Product>>((ref) {
  final companyId = ref.watch(authStateProvider).asData?.value?.activeCompanyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value(const <Product>[]);
  }

  return ref.watch(productRepositoryProvider).watchProducts(companyId);
});

class PricingPage extends ConsumerStatefulWidget {
  const PricingPage({super.key});

  static const routePath = '/pricing';
  static const routeName = 'pricing';

  @override
  ConsumerState<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<PricingPage> {
  final _formKey = GlobalKey<FormState>();
  final _productCostController = TextEditingController();
  final _additionalCostsController = TextEditingController(text: '0,00');
  final _fixedFeeController = TextEditingController(text: '0,00');
  final _percentageFeeController = TextEditingController(text: '0');
  final _desiredProfitController = TextEditingController();
  final _salePriceController = TextEditingController();

  _PricingMode _mode = _PricingMode.profitFromPrice;
  _ProfitTargetUnit _profitTargetUnit = _ProfitTargetUnit.currency;
  String? _selectedProductId;
  String? _selectedProductName;
  PricingResult? _result;

  @override
  void dispose() {
    _productCostController.dispose();
    _additionalCostsController.dispose();
    _fixedFeeController.dispose();
    _percentageFeeController.dispose();
    _desiredProfitController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(pricingProductsProvider);
    final products = productsState.maybeWhen(
      data: (value) => value.where((product) => product.isActive).toList(),
      orElse: () => const <Product>[],
    );

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Calculadora',
            subtitle: 'Precificação de produtos, custos, taxas e lucro',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 940;
              final form = _CalculatorForm(
                formKey: _formKey,
                mode: _mode,
                profitTargetUnit: _profitTargetUnit,
                products: products,
                productsLoading: productsState.isLoading,
                selectedProductId: _selectedProductId,
                productCostController: _productCostController,
                additionalCostsController: _additionalCostsController,
                fixedFeeController: _fixedFeeController,
                percentageFeeController: _percentageFeeController,
                desiredProfitController: _desiredProfitController,
                salePriceController: _salePriceController,
                onModeChanged: _changeMode,
                onProfitTargetUnitChanged: _changeProfitTargetUnit,
                onProductSelected: (productId) =>
                    _selectProduct(products, productId),
                onCalculate: _calculate,
                onClear: _clear,
              );
              final result = _CalculationResult(
                mode: _mode,
                result: _result,
                productName: _selectedProductName,
              );

              if (!isWide) {
                return Column(
                  children: [form, const SizedBox(height: 16), result],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: form),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: result),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _changeMode(_PricingMode mode) {
    if (_mode == mode) {
      return;
    }

    setState(() {
      _mode = mode;
      _result = null;
    });
  }

  void _changeProfitTargetUnit(_ProfitTargetUnit unit) {
    if (_profitTargetUnit == unit) {
      return;
    }

    setState(() {
      _profitTargetUnit = unit;
      _desiredProfitController.clear();
      _result = null;
    });
  }

  void _selectProduct(List<Product> products, String? productId) {
    if (productId == null || productId.isEmpty) {
      setState(() {
        _selectedProductId = null;
        _selectedProductName = null;
        _result = null;
      });
      return;
    }

    final product = products.firstWhere((item) => item.id == productId);
    setState(() {
      _selectedProductId = product.id;
      _selectedProductName = product.name;
      _productCostController.text = _editableDecimal(product.acquisitionCost);
      _salePriceController.text = _editableDecimal(product.salePrice);
      _result = null;
    });
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final platform = PricingPlatform(
      id: 'calculation',
      companyId: 'current',
      name: 'Cálculo atual',
      fees: [
        PricingFee(
          id: 'fixed',
          name: 'Taxa fixa',
          type: PricingFeeType.fixed,
          value: _parseDecimal(_fixedFeeController.text),
        ),
        PricingFee(
          id: 'percentage',
          name: 'Taxa percentual',
          type: PricingFeeType.percentage,
          value: _parseDecimal(_percentageFeeController.text) / 100,
        ),
      ],
    );

    final productCost = _parseDecimal(_productCostController.text);
    final additionalCosts = _parseDecimal(_additionalCostsController.text);
    final result = switch (_mode) {
      _PricingMode.profitFromPrice => PricingCalculator.profitFromPrice(
        ProfitFromPriceInput(
          productCost: productCost,
          additionalCosts: additionalCosts,
          salePrice: _parseDecimal(_salePriceController.text),
          platform: platform,
        ),
      ),
      _PricingMode.priceForProfit => switch (_profitTargetUnit) {
        _ProfitTargetUnit.currency => PricingCalculator.priceForTargetProfit(
          PriceForProfitInput(
            productCost: productCost,
            additionalCosts: additionalCosts,
            desiredProfit: _parseDecimal(_desiredProfitController.text),
            platform: platform,
          ),
        ),
        _ProfitTargetUnit.percentage => PricingCalculator.priceForTargetMargin(
          PriceForMarginInput(
            productCost: productCost,
            additionalCosts: additionalCosts,
            desiredMargin: _parseDecimal(_desiredProfitController.text) / 100,
            platform: platform,
          ),
        ),
      },
    };

    setState(() => _result = result);
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _productCostController.clear();
      _additionalCostsController.text = '0,00';
      _fixedFeeController.text = '0,00';
      _percentageFeeController.text = '0';
      _desiredProfitController.clear();
      _salePriceController.clear();
      _profitTargetUnit = _ProfitTargetUnit.currency;
      _result = null;
    });
  }
}

enum _PricingMode { profitFromPrice, priceForProfit }

enum _ProfitTargetUnit { currency, percentage }

class _CalculatorForm extends StatelessWidget {
  const _CalculatorForm({
    required this.formKey,
    required this.mode,
    required this.profitTargetUnit,
    required this.products,
    required this.productsLoading,
    required this.selectedProductId,
    required this.productCostController,
    required this.additionalCostsController,
    required this.fixedFeeController,
    required this.percentageFeeController,
    required this.desiredProfitController,
    required this.salePriceController,
    required this.onModeChanged,
    required this.onProfitTargetUnitChanged,
    required this.onProductSelected,
    required this.onCalculate,
    required this.onClear,
  });

  final GlobalKey<FormState> formKey;
  final _PricingMode mode;
  final _ProfitTargetUnit profitTargetUnit;
  final List<Product> products;
  final bool productsLoading;
  final String? selectedProductId;
  final TextEditingController productCostController;
  final TextEditingController additionalCostsController;
  final TextEditingController fixedFeeController;
  final TextEditingController percentageFeeController;
  final TextEditingController desiredProfitController;
  final TextEditingController salePriceController;
  final ValueChanged<_PricingMode> onModeChanged;
  final ValueChanged<_ProfitTargetUnit> onProfitTargetUnitChanged;
  final ValueChanged<String?> onProductSelected;
  final VoidCallback onCalculate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dados do cálculo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 440;

                  return SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_PricingMode>(
                      key: const Key('pricing-mode'),
                      segments: [
                        ButtonSegment(
                          value: _PricingMode.profitFromPrice,
                          icon: compact
                              ? null
                              : const Icon(Icons.query_stats_outlined),
                          label: const Text('Calcular lucro'),
                        ),
                        ButtonSegment(
                          value: _PricingMode.priceForProfit,
                          icon: compact
                              ? null
                              : const Icon(Icons.sell_outlined),
                          label: const Text('Calcular preço'),
                        ),
                      ],
                      selected: {mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          onModeChanged(selection.first),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              DropdownMenu<String>(
                key: ValueKey(selectedProductId ?? 'manual'),
                width: double.infinity,
                initialSelection: selectedProductId ?? '',
                requestFocusOnTap: true,
                enableFilter: true,
                enableSearch: true,
                leadingIcon: productsLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.inventory_2_outlined),
                label: const Text('Produto cadastrado (opcional)'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(
                    value: '',
                    label: 'Preenchimento manual',
                    leadingIcon: Icon(Icons.edit_outlined),
                  ),
                  for (final product in products)
                    DropdownMenuEntry(
                      value: product.id,
                      label: product.name,
                      leadingIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                ],
                onSelected: onProductSelected,
              ),
              const SizedBox(height: 18),
              _FieldGrid(
                children: [
                  _DecimalField(
                    fieldKey: const Key('pricing-product-cost'),
                    controller: productCostController,
                    label: 'Custo de aquisição',
                    prefixText: 'R\$ ',
                    icon: Icons.shopping_bag_outlined,
                    validator: (value) => _requiredMoneyValidator(
                      value,
                      emptyMessage: 'Informe o custo do produto.',
                    ),
                  ),
                  _DecimalField(
                    fieldKey: const Key('pricing-additional-costs'),
                    controller: additionalCostsController,
                    label: 'Custos adicionais',
                    prefixText: 'R\$ ',
                    icon: Icons.add_card_outlined,
                    validator: _optionalMoneyValidator,
                  ),
                  _DecimalField(
                    fieldKey: const Key('pricing-fixed-fee'),
                    controller: fixedFeeController,
                    label: 'Taxa fixa',
                    prefixText: 'R\$ ',
                    icon: Icons.payments_outlined,
                    validator: _optionalMoneyValidator,
                  ),
                  _DecimalField(
                    fieldKey: const Key('pricing-percentage-fee'),
                    controller: percentageFeeController,
                    label: 'Taxa percentual',
                    suffixText: '%',
                    icon: Icons.percent,
                    validator: _percentageValidator,
                  ),
                  if (mode == _PricingMode.priceForProfit)
                    _DesiredProfitField(
                      controller: desiredProfitController,
                      unit: profitTargetUnit,
                      percentageFeeController: percentageFeeController,
                      onUnitChanged: onProfitTargetUnitChanged,
                    )
                  else
                    _DecimalField(
                      fieldKey: const Key('pricing-sale-price'),
                      controller: salePriceController,
                      label: 'Preço de venda',
                      prefixText: 'R\$ ',
                      icon: Icons.sell_outlined,
                      validator: (value) => _requiredMoneyValidator(
                        value,
                        emptyMessage: 'Informe o preço de venda.',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 440;
                  final clearButton = TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Limpar'),
                  );
                  final calculateButton = FilledButton.icon(
                    onPressed: onCalculate,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Calcular'),
                  );

                  if (compact) {
                    return Row(
                      children: [
                        Expanded(child: clearButton),
                        const SizedBox(width: 10),
                        Expanded(child: calculateButton),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      clearButton,
                      const SizedBox(width: 10),
                      calculateButton,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _DesiredProfitField extends StatelessWidget {
  const _DesiredProfitField({
    required this.controller,
    required this.unit,
    required this.percentageFeeController,
    required this.onUnitChanged,
  });

  final TextEditingController controller;
  final _ProfitTargetUnit unit;
  final TextEditingController percentageFeeController;
  final ValueChanged<_ProfitTargetUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final input = _DecimalField(
      fieldKey: const Key('pricing-desired-profit'),
      controller: controller,
      label: unit == _ProfitTargetUnit.currency
          ? 'Lucro desejado em reais'
          : 'Margem desejada',
      prefixText: unit == _ProfitTargetUnit.currency ? 'R\$ ' : null,
      suffixText: unit == _ProfitTargetUnit.percentage ? '%' : null,
      icon: Icons.trending_up,
      validator: (value) {
        final requiredValidation = _requiredMoneyValidator(
          value,
          emptyMessage: 'Informe o lucro desejado.',
        );
        if (requiredValidation != null || unit == _ProfitTargetUnit.currency) {
          return requiredValidation;
        }

        return _targetMarginValidator(value, percentageFeeController.text);
      },
    );
    final selector = SegmentedButton<_ProfitTargetUnit>(
      key: const Key('pricing-profit-unit'),
      segments: const [
        ButtonSegment(value: _ProfitTargetUnit.currency, label: Text('R\$')),
        ButtonSegment(value: _ProfitTargetUnit.percentage, label: Text('%')),
      ],
      selected: {unit},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onUnitChanged(selection.first),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 390) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [input, const SizedBox(height: 8), selector],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: input),
            const SizedBox(width: 10),
            selector,
          ],
        );
      },
    );
  }
}

class _DecimalField extends StatelessWidget {
  const _DecimalField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.prefixText,
    this.suffixText,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final String? prefixText;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_decimalFormatter],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
        suffixText: suffixText,
      ),
      validator: validator,
      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
    );
  }
}

class _CalculationResult extends StatelessWidget {
  const _CalculationResult({
    required this.mode,
    required this.result,
    required this.productName,
  });

  final _PricingMode mode;
  final PricingResult? result;
  final String? productName;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const _EmptyResult();
    }

    final value = result!;
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final percent = NumberFormat.decimalPercentPattern(
      locale: 'pt_BR',
      decimalDigits: 1,
    );
    final fees = value.fixedFees + value.percentageFees;
    final totalCost = value.productCost + value.additionalCosts + fees;

    return Column(
      children: [
        DecoratedBox(
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        mode == _PricingMode.priceForProfit
                            ? Icons.sell_outlined
                            : Icons.trending_up,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mode == _PricingMode.priceForProfit
                            ? 'Preço de venda recomendado'
                            : 'Margem de lucro estimada',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  mode == _PricingMode.priceForProfit
                      ? currency.format(value.salePrice)
                      : percent.format(value.margin),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (productName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    productName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ResultPill(
                      label: 'Lucro',
                      value: currency.format(value.profit),
                    ),
                    if (mode == _PricingMode.priceForProfit)
                      _ResultPill(
                        label: 'Margem',
                        value: percent.format(value.margin),
                      )
                    else
                      _ResultPill(
                        label: 'Preço mínimo',
                        value: currency.format(value.minimumPrice),
                      ),
                    _ResultPill(label: 'Taxas', value: currency.format(fees)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo do cálculo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _SummaryLine(
                  label: 'Preço de venda',
                  value: currency.format(value.salePrice),
                ),
                _SummaryLine(
                  label: 'Custo de aquisição',
                  value: currency.format(value.productCost),
                ),
                _SummaryLine(
                  label: 'Custos adicionais',
                  value: currency.format(value.additionalCosts),
                ),
                _SummaryLine(
                  label: 'Taxas fixas',
                  value: currency.format(value.fixedFees),
                ),
                _SummaryLine(
                  label: 'Taxas percentuais',
                  value: currency.format(value.percentageFees),
                ),
                const Divider(height: 24),
                _SummaryLine(
                  label: 'Custo total',
                  value: currency.format(totalCost),
                  emphasized: true,
                ),
                _SummaryLine(
                  label: 'Lucro estimado',
                  value: currency.format(value.profit),
                  emphasized: true,
                  valueColor: value.profit < 0
                      ? Theme.of(context).colorScheme.error
                      : AppTheme.success,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 310),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calculate_outlined,
                  color: colors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Resultado do cálculo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Os valores calculados aparecerão aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
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

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'));

String? _requiredMoneyValidator(String? value, {required String emptyMessage}) {
  if (value == null || value.trim().isEmpty) {
    return emptyMessage;
  }
  return _optionalMoneyValidator(value);
}

String? _optionalMoneyValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  if (_tryParseDecimal(value) == null) {
    return 'Informe um valor válido.';
  }
  return null;
}

String? _percentageValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final percentage = _tryParseDecimal(value);
  if (percentage == null || percentage < 0 || percentage >= 100) {
    return 'Informe uma taxa entre 0 e 99,99%.';
  }
  return null;
}

String? _targetMarginValidator(String? value, String percentageFeeValue) {
  final margin = _tryParseDecimal(value ?? '');
  if (margin == null || margin < 0 || margin >= 100) {
    return 'Informe uma margem entre 0 e 99,99%.';
  }

  final percentageFee = _tryParseDecimal(percentageFeeValue) ?? 0;
  if (margin + percentageFee >= 100) {
    return 'Margem e taxa somadas devem ser menores que 100%.';
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
