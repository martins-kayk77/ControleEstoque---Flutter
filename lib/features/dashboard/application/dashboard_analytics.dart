import '../../inventory/domain/product.dart';
import '../../inventory/domain/stock_movement.dart';

enum DashboardPeriod { last7Days, last30Days, last90Days, all }

extension DashboardPeriodX on DashboardPeriod {
  String get label {
    return switch (this) {
      DashboardPeriod.last7Days => 'Últimos 7 dias',
      DashboardPeriod.last30Days => 'Últimos 30 dias',
      DashboardPeriod.last90Days => 'Últimos 90 dias',
      DashboardPeriod.all => 'Todo o período',
    };
  }

  int? get dayCount {
    return switch (this) {
      DashboardPeriod.last7Days => 7,
      DashboardPeriod.last30Days => 30,
      DashboardPeriod.last90Days => 90,
      DashboardPeriod.all => null,
    };
  }
}

class DashboardAnalytics {
  const DashboardAnalytics({
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.saleCount,
    required this.unitsSold,
    required this.products,
    required this.series,
    required this.stockCostValue,
    required this.potentialSaleValue,
  });

  factory DashboardAnalytics.calculate({
    required List<Product> products,
    required List<StockMovement> movements,
    required DashboardPeriod period,
    DateTime? now,
  }) {
    final referenceDate = now ?? DateTime.now();
    final endDate = _dateOnly(referenceDate);
    final configuredDays = period.dayCount;
    final configuredStart = configuredDays == null
        ? null
        : endDate.subtract(Duration(days: configuredDays - 1));
    final productsById = {for (final product in products) product.id: product};
    final sales = movements.where((movement) {
      if (movement.type != StockMovementType.sale ||
          movement.quantityDelta >= 0 ||
          movement.isReversal ||
          movement.isReversed) {
        return false;
      }

      final occurredOn = _dateOnly(movement.occurredAt);
      return !occurredOn.isAfter(endDate) &&
          (configuredStart == null || !occurredOn.isBefore(configuredStart));
    }).toList();

    var revenue = 0.0;
    var cost = 0.0;
    var unitsSold = 0;
    final operationIds = <String>{};
    final productTotals = <String, _MutableProductPerformance>{};
    final dailyTotals = <DateTime, _MutableSeriesPoint>{};

    for (final movement in sales) {
      final product = productsById[movement.productId];
      final quantity = movement.quantityDelta.abs();
      final itemRevenue = (product?.salePrice ?? 0) * quantity;
      final itemCost = (product?.acquisitionCost ?? 0) * quantity;
      final itemProfit = itemRevenue - itemCost;
      final operationId = movement.operationId;

      revenue += itemRevenue;
      cost += itemCost;
      unitsSold += quantity;
      operationIds.add(
        operationId == null || operationId.isEmpty ? movement.id : operationId,
      );

      final productTotal = productTotals.putIfAbsent(
        movement.productId,
        () => _MutableProductPerformance(
          productId: movement.productId,
          productName: product?.name ?? 'Produto removido',
        ),
      );
      productTotal
        ..unitsSold += quantity
        ..revenue += itemRevenue
        ..cost += itemCost;

      final saleDate = _dateOnly(movement.occurredAt);
      final dailyTotal = dailyTotals.putIfAbsent(
        saleDate,
        () => _MutableSeriesPoint(),
      );
      dailyTotal
        ..revenue += itemRevenue
        ..profit += itemProfit;
    }

    final rankedProducts = productTotals.values
        .map(
          (item) => DashboardProductPerformance(
            productId: item.productId,
            productName: item.productName,
            unitsSold: item.unitsSold,
            revenue: item.revenue,
            cost: item.cost,
          ),
        )
        .toList();

    final firstSaleDate = sales.isEmpty
        ? endDate
        : sales
              .map((movement) => _dateOnly(movement.occurredAt))
              .reduce(
                (first, second) => first.isBefore(second) ? first : second,
              );
    final seriesStart = configuredStart ?? firstSaleDate;

    return DashboardAnalytics(
      revenue: revenue,
      cost: cost,
      profit: revenue - cost,
      saleCount: operationIds.length,
      unitsSold: unitsSold,
      products: rankedProducts,
      series: _buildSeries(
        dailyTotals: dailyTotals,
        start: seriesStart,
        end: endDate,
      ),
      stockCostValue: products.fold(
        0,
        (total, product) => total + product.stockCostValue,
      ),
      potentialSaleValue: products.fold(
        0,
        (total, product) => total + product.potentialSaleValue,
      ),
    );
  }

  final double revenue;
  final double cost;
  final double profit;
  final int saleCount;
  final int unitsSold;
  final List<DashboardProductPerformance> products;
  final List<DashboardSeriesPoint> series;
  final double stockCostValue;
  final double potentialSaleValue;

  double get margin => revenue == 0 ? 0 : profit / revenue;
  double get averageTicket => saleCount == 0 ? 0 : revenue / saleCount;

  List<DashboardProductPerformance> get bestSellingProducts {
    final result = [...products]
      ..sort((first, second) {
        final byUnits = second.unitsSold.compareTo(first.unitsSold);
        if (byUnits != 0) return byUnits;
        return second.revenue.compareTo(first.revenue);
      });
    return result;
  }

  List<DashboardProductPerformance> get mostProfitableProducts {
    final result = [...products]
      ..sort((first, second) => second.profit.compareTo(first.profit));
    return result;
  }
}

class DashboardProductPerformance {
  const DashboardProductPerformance({
    required this.productId,
    required this.productName,
    required this.unitsSold,
    required this.revenue,
    required this.cost,
  });

  final String productId;
  final String productName;
  final int unitsSold;
  final double revenue;
  final double cost;

  double get profit => revenue - cost;
}

class DashboardSeriesPoint {
  const DashboardSeriesPoint({
    required this.start,
    required this.end,
    required this.revenue,
    required this.profit,
  });

  final DateTime start;
  final DateTime end;
  final double revenue;
  final double profit;
}

List<DashboardSeriesPoint> _buildSeries({
  required Map<DateTime, _MutableSeriesPoint> dailyTotals,
  required DateTime start,
  required DateTime end,
}) {
  final rangeInDays = end.difference(start).inDays + 1;
  final bucketSize = (rangeInDays / 12).ceil().clamp(1, rangeInDays);
  final result = <DashboardSeriesPoint>[];

  for (
    var bucketStart = start;
    !bucketStart.isAfter(end);
    bucketStart = bucketStart.add(Duration(days: bucketSize))
  ) {
    final proposedEnd = bucketStart.add(Duration(days: bucketSize - 1));
    final bucketEnd = proposedEnd.isAfter(end) ? end : proposedEnd;
    var revenue = 0.0;
    var profit = 0.0;

    for (
      var day = bucketStart;
      !day.isAfter(bucketEnd);
      day = day.add(const Duration(days: 1))
    ) {
      final total = dailyTotals[day];
      revenue += total?.revenue ?? 0;
      profit += total?.profit ?? 0;
    }

    result.add(
      DashboardSeriesPoint(
        start: bucketStart,
        end: bucketEnd,
        revenue: revenue,
        profit: profit,
      ),
    );
  }

  return result;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _MutableProductPerformance {
  _MutableProductPerformance({
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;
  int unitsSold = 0;
  double revenue = 0;
  double cost = 0;
}

class _MutableSeriesPoint {
  double revenue = 0;
  double profit = 0;
}
