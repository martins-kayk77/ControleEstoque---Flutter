import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../domain/stock_movement.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(ref.watch(firebaseFirestoreProvider));
});

class StockMovementRequest {
  const StockMovementRequest({
    required this.productId,
    required this.quantityDelta,
  });

  final String productId;
  final int quantityDelta;
}

class InventoryService {
  const InventoryService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> applyMovement({
    required String companyId,
    required String productId,
    required StockMovementType type,
    required int quantityDelta,
    String? userId,
    String reason = '',
    String note = '',
    String? sourceChannelId,
    DateTime? occurredAt,
  }) {
    return applyMovements(
      companyId: companyId,
      items: [
        StockMovementRequest(
          productId: productId,
          quantityDelta: quantityDelta,
        ),
      ],
      type: type,
      userId: userId,
      reason: reason,
      note: note,
      sourceChannelId: sourceChannelId,
      occurredAt: occurredAt,
    );
  }

  Future<void> applyMovements({
    required String companyId,
    required List<StockMovementRequest> items,
    required StockMovementType type,
    String? userId,
    String reason = '',
    String note = '',
    String? sourceChannelId,
    DateTime? occurredAt,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'Informe ao menos um produto.');
    }

    final productIds = <String>{};
    for (final item in items) {
      if (item.quantityDelta == 0) {
        throw ArgumentError.value(
          item.quantityDelta,
          'quantityDelta',
          'A quantidade não pode ser zero.',
        );
      }
      if (!productIds.add(item.productId)) {
        throw ArgumentError.value(
          item.productId,
          'productId',
          'O produto não pode aparecer mais de uma vez.',
        );
      }
    }

    final productRefs = [
      for (final item in items)
        _firestore.doc(FirestorePaths.product(companyId, item.productId)),
    ];
    final movementCollection = _firestore.collection(
      FirestorePaths.movements(companyId),
    );
    final operationId = movementCollection.doc().id;
    final movementRefs = [
      for (var index = 0; index < items.length; index++)
        movementCollection.doc(),
    ];
    final effectiveOccurredAt = occurredAt ?? DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final nextStocks = List<int>.filled(items.length, 0);

      for (var index = 0; index < items.length; index++) {
        final productSnapshot = await transaction.get(productRefs[index]);
        final productData = productSnapshot.data();

        if (!productSnapshot.exists || productData == null) {
          throw StateError('Produto não encontrado.');
        }

        final currentStock =
            (productData['currentStock'] as num?)?.toInt() ?? 0;
        final nextStock = currentStock + items[index].quantityDelta;

        if (nextStock < 0) {
          throw StateError('Movimentação deixaria o estoque negativo.');
        }
        nextStocks[index] = nextStock;
      }

      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final nextStock = nextStocks[index];

        transaction.update(productRefs[index], {
          'currentStock': nextStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(movementRefs[index], {
          'companyId': companyId,
          'productId': item.productId,
          'type': type.code,
          'quantityDelta': item.quantityDelta,
          'occurredAt': Timestamp.fromDate(effectiveOccurredAt),
          'operationId': operationId,
          'userId': userId,
          'reason': reason,
          'note': note,
          'sourceChannelId': sourceChannelId,
          'stockAfter': nextStock,
        });
      }
    });
  }

  Future<void> applyCountDifference({
    required String companyId,
    required String productId,
    required int expectedQuantity,
    required int countedQuantity,
    String? userId,
    String reason = '',
  }) {
    final difference = countedQuantity - expectedQuantity;

    if (difference == 0) {
      return Future.value();
    }

    return applyMovement(
      companyId: companyId,
      productId: productId,
      type: StockMovementType.adjustment,
      quantityDelta: difference,
      userId: userId,
      reason: reason,
      note: 'Ajuste gerado por contagem de estoque.',
    );
  }
}
