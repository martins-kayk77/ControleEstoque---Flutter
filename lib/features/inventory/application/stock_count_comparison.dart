import '../domain/stock_count.dart';

class StockCountDifference {
  const StockCountDifference(this.before, this.after);
  final StockCountItem? before;
  final StockCountItem? after;
  String get productId => (after ?? before)!.productId;
  String get name => (after ?? before)!.productName;
  bool get added => before == null;
  bool get removed => after == null;
  bool get comparable =>
      before != null && after != null && before!.unit == after!.unit;
  int? get variation =>
      comparable ? after!.countedQuantity! - before!.countedQuantity! : null;
  int? get registeredVariation =>
      comparable ? after!.expectedQuantity - before!.countedQuantity! : null;
  bool get changed =>
      !comparable ||
      before!.productName != after!.productName ||
      before!.expectedQuantity != after!.expectedQuantity ||
      before!.countedQuantity != after!.countedQuantity ||
      before!.difference != after!.difference ||
      before!.reason != after!.reason;
}

List<StockCountDifference> compareStockCounts(
  StockCount before,
  StockCount after,
) {
  if (before.companyId != after.companyId ||
      before.id == after.id ||
      before.status != StockCountStatus.completed ||
      after.status != StockCountStatus.completed) {
    throw ArgumentError(
      'Selecione dois relatórios concluídos da mesma empresa.',
    );
  }
  final oldItems = {for (final item in before.items) item.productId: item};
  final newItems = {for (final item in after.items) item.productId: item};
  final rows = [
    for (final id in {...oldItems.keys, ...newItems.keys})
      StockCountDifference(oldItems[id], newItems[id]),
  ];
  rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return rows;
}
