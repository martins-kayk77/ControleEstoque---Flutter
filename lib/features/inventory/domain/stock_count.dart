enum StockCountStatus { draft, inProgress, completed, canceled }

class StockCount {
  const StockCount({
    required this.id,
    required this.companyId,
    required this.startedAt,
    required this.status,
    this.completedAt,
    this.responsibleUserId,
    this.itemsCount = 0,
    this.responsibleName = '',
    this.note = '',
    this.items = const [],
    this.operationId,
    this.revision = 0,
    this.adjustedAt,
    this.adjustedByUserId,
    this.adjustedByName = '',
    this.number,
  });

  final String id;
  final String companyId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final StockCountStatus status;
  final String? responsibleUserId;
  final int itemsCount;
  final String responsibleName;
  final String note;
  final List<StockCountItem> items;
  final String? operationId;
  final int revision;
  final DateTime? adjustedAt;
  final String? adjustedByUserId;
  final String adjustedByName;
  final int? number;

  String? get code =>
      number == null ? null : 'CT-${number.toString().padLeft(4, '0')}';

  // Older reports already applied their adjustments during completion.
  bool get stockAdjusted =>
      adjustedAt != null || (operationId?.isNotEmpty ?? false);

  StockCount withProgress(List<StockCountItem> items, int revision) =>
      StockCount(
        id: id,
        companyId: companyId,
        startedAt: startedAt,
        status: status,
        completedAt: completedAt,
        responsibleUserId: responsibleUserId,
        itemsCount: itemsCount,
        responsibleName: responsibleName,
        note: note,
        items: items,
        operationId: operationId,
        revision: revision,
        adjustedAt: adjustedAt,
        adjustedByUserId: adjustedByUserId,
        adjustedByName: adjustedByName,
        number: number,
      );

  bool get isOpen =>
      status == StockCountStatus.inProgress || status == StockCountStatus.draft;
  int get countedItems => items.where((item) => item.isCounted).length;
  int get divergentItems =>
      items.where((item) => item.isCounted && item.difference != 0).length;
  int get totalUnits =>
      items.fold(0, (sum, item) => sum + (item.countedQuantity ?? 0));
  int get missingUnits => items
      .where((item) => item.difference < 0)
      .fold(0, (sum, item) => sum - item.difference);
  int get surplusUnits => items
      .where((item) => item.difference > 0)
      .fold(0, (sum, item) => sum + item.difference);
}

class StockCountItem {
  const StockCountItem({
    required this.id,
    required this.productId,
    required this.expectedQuantity,
    required this.countedQuantity,
    this.reason = '',
    this.productName = '',
    this.unit = 'un',
    this.acquisitionCost = 0,
    this.productUpdatedAt,
  });

  final String id;
  final String productId;
  final int expectedQuantity;
  final int? countedQuantity;
  final String reason;
  final String productName;
  final String unit;
  final double acquisitionCost;
  final DateTime? productUpdatedAt;

  bool get isCounted => countedQuantity != null;
  int get difference => isCounted ? countedQuantity! - expectedQuantity : 0;

  StockCountItem withCount(int? quantity, String reason) => StockCountItem(
    id: id,
    productId: productId,
    expectedQuantity: expectedQuantity,
    countedQuantity: quantity,
    reason: reason,
    productName: productName,
    unit: unit,
    acquisitionCost: acquisitionCost,
    productUpdatedAt: productUpdatedAt,
  );
}
