import 'package:controle_estoque/features/inventory/application/stock_count_comparison.dart';
import 'package:controle_estoque/features/inventory/domain/stock_count.dart';
import 'package:flutter_test/flutter_test.dart';

StockCount report(
  String id,
  List<StockCountItem> items, {
  String company = 'c',
}) => StockCount(
  id: id,
  companyId: company,
  startedAt: DateTime(2026, 10, 1),
  completedAt: DateTime(2026, 10, 2),
  status: StockCountStatus.completed,
  items: items,
);
StockCountItem item(String id, int expected, int found, {String unit = 'un'}) =>
    StockCountItem(
      id: id,
      productId: id,
      productName: 'Produto $id',
      unit: unit,
      expectedQuantity: expected,
      countedQuantity: found,
    );

void main() {
  test('distingue movimentações registradas de divergência física', () {
    final before = report('1', [item('a', 20, 20), item('b', 10, 10)]);
    final after = report('2', [item('a', 17, 15), item('b', 7, 7)]);
    final rows = compareStockCounts(before, after);
    expect(rows[0].variation, -5);
    expect(rows[0].registeredVariation, -3);
    expect(rows[0].after!.difference, -2);
    expect(rows[1].variation, -3);
    expect(rows[1].after!.difference, 0);
  });
  test('identifica incluídos, ausentes e produtos sem diferenças', () {
    final rows = compareStockCounts(
      report('1', [item('a', 2, 2), item('b', 4, 4)]),
      report('2', [item('a', 2, 2), item('c', 5, 5)]),
    );
    expect(rows[0].changed, isFalse);
    expect(rows[1].removed, isTrue);
    expect(rows[1].variation, isNull);
    expect(rows[2].added, isTrue);
  });
  test(
    'não compara quantidades de unidades diferentes nem empresas distintas',
    () {
      final rows = compareStockCounts(
        report('1', [item('a', 2, 2)]),
        report('2', [item('a', 2, 2, unit: 'cx')]),
      );
      expect(rows.single.comparable, isFalse);
      expect(rows.single.changed, isTrue);
      expect(
        () => compareStockCounts(
          report('1', []),
          report('2', [], company: 'other'),
        ),
        throwsArgumentError,
      );
    },
  );
}
