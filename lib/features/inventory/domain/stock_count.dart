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
  });

  final String id;
  final String companyId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final StockCountStatus status;
  final String? responsibleUserId;
  final int itemsCount;
}

class StockCountItem {
  const StockCountItem({
    required this.id,
    required this.productId,
    required this.expectedQuantity,
    required this.countedQuantity,
    this.reason = '',
  });

  final String id;
  final String productId;
  final int expectedQuantity;
  final int countedQuantity;
  final String reason;

  int get difference => countedQuantity - expectedQuantity;
}
