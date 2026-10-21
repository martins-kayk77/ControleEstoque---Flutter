import '../domain/pricing_models.dart';

class PricingCalculator {
  const PricingCalculator._();

  static PricingResult priceForTargetProfit(PriceForProfitInput input) {
    _validateMoney('productCost', input.productCost);
    _validateMoney('additionalCosts', input.additionalCosts);
    _validateMoney('desiredProfit', input.desiredProfit);

    final rate = _validateRate(input.platform.percentageRate);
    final baseCost =
        input.productCost + input.additionalCosts + input.platform.fixedFees;
    final salePrice = _ceilCurrency(
      (baseCost + input.desiredProfit) / (1 - rate),
    );

    return _buildResult(
      salePrice: salePrice,
      productCost: input.productCost,
      additionalCosts: input.additionalCosts,
      platform: input.platform,
    );
  }

  static PricingResult priceForTargetMargin(PriceForMarginInput input) {
    _validateMoney('productCost', input.productCost);
    _validateMoney('additionalCosts', input.additionalCosts);

    final rate = _validateRate(input.platform.percentageRate);
    final desiredMargin = _validateRate(input.desiredMargin);
    final retainedRate = 1 - rate - desiredMargin;
    if (retainedRate <= 0) {
      throw ArgumentError.value(
        input.desiredMargin,
        'desiredMargin',
        'A soma da margem desejada e das taxas deve ser menor que 100%.',
      );
    }

    final baseCost =
        input.productCost + input.additionalCosts + input.platform.fixedFees;
    final salePrice = _ceilCurrency(baseCost / retainedRate);

    return _buildResult(
      salePrice: salePrice,
      productCost: input.productCost,
      additionalCosts: input.additionalCosts,
      platform: input.platform,
    );
  }

  static PricingResult profitFromPrice(ProfitFromPriceInput input) {
    _validateMoney('productCost', input.productCost);
    _validateMoney('additionalCosts', input.additionalCosts);
    _validateMoney('salePrice', input.salePrice);
    _validateRate(input.platform.percentageRate);

    return _buildResult(
      salePrice: _roundCurrency(input.salePrice),
      productCost: input.productCost,
      additionalCosts: input.additionalCosts,
      platform: input.platform,
    );
  }

  static double minimumPrice({
    required double productCost,
    required double additionalCosts,
    required PricingPlatform platform,
  }) {
    _validateMoney('productCost', productCost);
    _validateMoney('additionalCosts', additionalCosts);

    final rate = _validateRate(platform.percentageRate);
    final baseCost = productCost + additionalCosts + platform.fixedFees;

    return _ceilCurrency(baseCost / (1 - rate));
  }

  static PricingResult _buildResult({
    required double salePrice,
    required double productCost,
    required double additionalCosts,
    required PricingPlatform platform,
  }) {
    final rate = _validateRate(platform.percentageRate);
    final fixedFees = _roundCurrency(platform.fixedFees);
    final percentageFees = _roundCurrency(salePrice * rate);
    final minimum = minimumPrice(
      productCost: productCost,
      additionalCosts: additionalCosts,
      platform: platform,
    );
    final profit = _roundCurrency(
      salePrice - productCost - additionalCosts - fixedFees - percentageFees,
    );

    return PricingResult(
      salePrice: salePrice,
      productCost: _roundCurrency(productCost),
      additionalCosts: _roundCurrency(additionalCosts),
      fixedFees: fixedFees,
      percentageFees: percentageFees,
      profit: profit,
      margin: salePrice == 0 ? 0 : profit / salePrice,
      minimumPrice: minimum,
    );
  }

  static void _validateMoney(String name, double value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      throw ArgumentError.value(value, name, 'Valor monetário inválido.');
    }
  }

  static double _validateRate(double rate) {
    if (rate.isNaN || rate.isInfinite || rate < 0 || rate >= 1) {
      throw ArgumentError.value(rate, 'percentageRate', 'Taxa inválida.');
    }

    return rate;
  }

  static double _roundCurrency(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  static double _ceilCurrency(double value) {
    return (value * 100).ceilToDouble() / 100;
  }
}
