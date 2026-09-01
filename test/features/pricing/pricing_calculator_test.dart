import 'package:controle_estoque/features/pricing/application/pricing_calculator.dart';
import 'package:controle_estoque/features/pricing/domain/pricing_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const platform = PricingPlatform(
    id: 'mercado',
    companyId: 'company',
    name: 'Canal com comissão',
    fees: [
      PricingFee(
        id: 'commission',
        name: 'Comissão',
        type: PricingFeeType.percentage,
        value: 0.10,
      ),
    ],
  );

  test('calcula preço para lucro desejado sobre preço final', () {
    final result = PricingCalculator.priceForTargetProfit(
      const PriceForProfitInput(
        productCost: 40,
        additionalCosts: 3,
        desiredProfit: 20,
        platform: platform,
      ),
    );

    expect(result.salePrice, 70);
    expect(result.percentageFees, 7);
    expect(result.profit, 20);
    expect(result.margin, closeTo(0.2857, 0.0001));
  });

  test('calcula lucro a partir de preço informado', () {
    final result = PricingCalculator.profitFromPrice(
      const ProfitFromPriceInput(
        productCost: 40,
        additionalCosts: 3,
        salePrice: 75,
        platform: platform,
      ),
    );

    expect(result.percentageFees, 7.5);
    expect(result.profit, 24.5);
    expect(result.margin, closeTo(0.3266, 0.0001));
  });

  test('calcula preço mínimo para não ter prejuízo', () {
    final result = PricingCalculator.minimumPrice(
      productCost: 40,
      additionalCosts: 3,
      platform: platform,
    );

    expect(result, 47.78);
  });
}
