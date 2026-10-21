import 'package:controle_estoque/features/dashboard/application/dashboard_analytics.dart';
import 'package:controle_estoque/features/inventory/domain/product.dart';
import 'package:controle_estoque/features/inventory/domain/stock_movement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 20, 18);
  final products = [
    _product(
      id: 'product-a',
      name: 'Produto A',
      acquisitionCost: 10,
      salePrice: 20,
      currentStock: 8,
    ),
    _product(
      id: 'product-b',
      name: 'Produto B',
      acquisitionCost: 5,
      salePrice: 15,
      currentStock: 4,
    ),
  ];

  test('calcula vendas por operação e ignora movimentações estornadas', () {
    final analytics = DashboardAnalytics.calculate(
      products: products,
      movements: [
        _sale(
          id: 'movement-1',
          productId: 'product-a',
          quantity: 2,
          operationId: '1000',
          occurredAt: now,
        ),
        _sale(
          id: 'movement-2',
          productId: 'product-b',
          quantity: 1,
          operationId: '1000',
          occurredAt: now,
        ),
        _sale(
          id: 'movement-3',
          productId: 'product-a',
          quantity: 1,
          operationId: '1001',
          occurredAt: now,
          reversalOperationId: '1002',
        ),
        _movement(
          id: 'movement-4',
          productId: 'product-a',
          type: StockMovementType.reversal,
          quantityDelta: 1,
          operationId: '1002',
          occurredAt: now,
        ),
      ],
      period: DashboardPeriod.last7Days,
      now: now,
    );

    expect(analytics.saleCount, 1);
    expect(analytics.unitsSold, 3);
    expect(analytics.revenue, 55);
    expect(analytics.cost, 25);
    expect(analytics.profit, 30);
    expect(analytics.averageTicket, 55);
    expect(analytics.margin, closeTo(30 / 55, 0.0001));
    expect(analytics.bestSellingProducts.first.productName, 'Produto A');
    expect(analytics.series, hasLength(7));
  });

  test('respeita o período selecionado', () {
    final movements = [
      _sale(
        id: 'recent-sale',
        productId: 'product-a',
        quantity: 2,
        operationId: '1000',
        occurredAt: now,
      ),
      _sale(
        id: 'older-sale',
        productId: 'product-a',
        quantity: 5,
        operationId: '999',
        occurredAt: now.subtract(const Duration(days: 10)),
      ),
    ];

    final last7Days = DashboardAnalytics.calculate(
      products: products,
      movements: movements,
      period: DashboardPeriod.last7Days,
      now: now,
    );
    final last30Days = DashboardAnalytics.calculate(
      products: products,
      movements: movements,
      period: DashboardPeriod.last30Days,
      now: now,
    );

    expect(last7Days.saleCount, 1);
    expect(last7Days.revenue, 40);
    expect(last30Days.saleCount, 2);
    expect(last30Days.revenue, 140);
  });

  test('calcula a posição financeira do estoque atual', () {
    final analytics = DashboardAnalytics.calculate(
      products: products,
      movements: const [],
      period: DashboardPeriod.last30Days,
      now: now,
    );

    expect(analytics.stockCostValue, 100);
    expect(analytics.potentialSaleValue, 220);
  });
}

Product _product({
  required String id,
  required String name,
  required double acquisitionCost,
  required double salePrice,
  required int currentStock,
}) {
  return Product(
    id: id,
    companyId: 'company',
    name: name,
    acquisitionCost: acquisitionCost,
    salePrice: salePrice,
    currentStock: currentStock,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

StockMovement _sale({
  required String id,
  required String productId,
  required int quantity,
  required String operationId,
  required DateTime occurredAt,
  String? reversalOperationId,
}) {
  return _movement(
    id: id,
    productId: productId,
    type: StockMovementType.sale,
    quantityDelta: -quantity,
    operationId: operationId,
    occurredAt: occurredAt,
    reversalOperationId: reversalOperationId,
  );
}

StockMovement _movement({
  required String id,
  required String productId,
  required StockMovementType type,
  required int quantityDelta,
  required String operationId,
  required DateTime occurredAt,
  String? reversalOperationId,
}) {
  return StockMovement(
    id: id,
    companyId: 'company',
    productId: productId,
    type: type,
    quantityDelta: quantityDelta,
    occurredAt: occurredAt,
    operationId: operationId,
    reversalOperationId: reversalOperationId,
  );
}
