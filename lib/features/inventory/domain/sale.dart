class Sale {
  const Sale({
    required this.id,
    required this.companyId,
    required this.soldAt,
    required this.items,
    this.channelId,
    this.customerName = '',
    this.grossAmount = 0,
    this.totalCost = 0,
    this.totalFees = 0,
  });

  final String id;
  final String companyId;
  final DateTime soldAt;
  final String? channelId;
  final String customerName;
  final List<SaleItem> items;
  final double grossAmount;
  final double totalCost;
  final double totalFees;

  double get profit => grossAmount - totalCost - totalFees;
  double get margin => grossAmount == 0 ? 0 : profit / grossAmount;
}

class SaleItem {
  const SaleItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  final String productId;
  final int quantity;
  final double unitPrice;
  final double unitCost;

  double get grossAmount => unitPrice * quantity;
  double get costAmount => unitCost * quantity;
}
