class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.categoryId,
    this.acquisitionCost = 0,
    this.salePrice = 0,
    this.currentStock = 0,
    this.minimumStock = 0,
    this.reorderPoint = 0,
    this.unit = 'un',
    this.supplier = '',
    this.isActive = true,
    this.metadata = const {},
  });

  final String id;
  final String companyId;
  final String name;
  final String description;
  final String? categoryId;
  final double acquisitionCost;
  final double salePrice;
  final int currentStock;
  final int minimumStock;
  final int reorderPoint;
  final String unit;
  final String supplier;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> metadata;

  bool get isOutOfStock => currentStock <= 0;
  bool get isBelowMinimum => currentStock <= minimumStock;
  bool get shouldReorder => currentStock <= reorderPoint;
  double get stockCostValue => acquisitionCost * currentStock;
  double get potentialSaleValue => salePrice * currentStock;
  double get potentialProfit => potentialSaleValue - stockCostValue;

  Product copyWith({
    String? id,
    String? companyId,
    String? name,
    String? description,
    String? categoryId,
    double? acquisitionCost,
    double? salePrice,
    int? currentStock,
    int? minimumStock,
    int? reorderPoint,
    String? unit,
    String? supplier,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
  }) {
    return Product(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      acquisitionCost: acquisitionCost ?? this.acquisitionCost,
      salePrice: salePrice ?? this.salePrice,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      unit: unit ?? this.unit,
      supplier: supplier ?? this.supplier,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
