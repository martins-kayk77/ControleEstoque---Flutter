enum PricingFeeType { fixed, percentage }

extension PricingFeeTypeX on PricingFeeType {
  String get code {
    return switch (this) {
      PricingFeeType.fixed => 'fixed',
      PricingFeeType.percentage => 'percentage',
    };
  }
}

PricingFeeType pricingFeeTypeFromCode(String code) {
  return PricingFeeType.values.firstWhere(
    (type) => type.code == code,
    orElse: () => PricingFeeType.fixed,
  );
}

class PricingFee {
  const PricingFee({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.isActive = true,
  });

  final String id;
  final String name;
  final PricingFeeType type;
  final double value;
  final bool isActive;
}

class PricingPlatform {
  const PricingPlatform({
    required this.id,
    required this.companyId,
    required this.name,
    this.fees = const [],
    this.isActive = true,
  });

  final String id;
  final String companyId;
  final String name;
  final List<PricingFee> fees;
  final bool isActive;

  double get fixedFees {
    return fees
        .where((fee) => fee.isActive && fee.type == PricingFeeType.fixed)
        .fold(0, (total, fee) => total + fee.value);
  }

  double get percentageRate {
    return fees
        .where((fee) => fee.isActive && fee.type == PricingFeeType.percentage)
        .fold(0, (total, fee) => total + fee.value);
  }
}

class PriceForProfitInput {
  const PriceForProfitInput({
    required this.productCost,
    required this.additionalCosts,
    required this.desiredProfit,
    required this.platform,
  });

  final double productCost;
  final double additionalCosts;
  final double desiredProfit;
  final PricingPlatform platform;
}

class ProfitFromPriceInput {
  const ProfitFromPriceInput({
    required this.productCost,
    required this.additionalCosts,
    required this.salePrice,
    required this.platform,
  });

  final double productCost;
  final double additionalCosts;
  final double salePrice;
  final PricingPlatform platform;
}

class PricingResult {
  const PricingResult({
    required this.salePrice,
    required this.productCost,
    required this.additionalCosts,
    required this.fixedFees,
    required this.percentageFees,
    required this.profit,
    required this.margin,
    required this.minimumPrice,
  });

  final double salePrice;
  final double productCost;
  final double additionalCosts;
  final double fixedFees;
  final double percentageFees;
  final double profit;
  final double margin;
  final double minimumPrice;
}
