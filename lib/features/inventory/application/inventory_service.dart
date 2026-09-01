import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../domain/stock_movement.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(ref.watch(firebaseFirestoreProvider));
});

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
  }) async {
    if (quantityDelta == 0) {
      throw ArgumentError.value(quantityDelta, 'quantityDelta');
    }

    final productRef = _firestore.doc(
      FirestorePaths.product(companyId, productId),
    );
    final movementRef = _firestore
        .collection(FirestorePaths.movements(companyId))
        .doc();
    final effectiveOccurredAt = occurredAt ?? DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      final productData = productSnapshot.data();

      if (!productSnapshot.exists || productData == null) {
        throw StateError('Produto não encontrado.');
      }

      final currentStock = (productData['currentStock'] as num?)?.toInt() ?? 0;
      final nextStock = currentStock + quantityDelta;

      if (nextStock < 0) {
        throw StateError('Movimentação deixaria o estoque negativo.');
      }

      transaction.update(productRef, {
        'currentStock': nextStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(movementRef, {
        'companyId': companyId,
        'productId': productId,
        'type': type.code,
        'quantityDelta': quantityDelta,
        'occurredAt': Timestamp.fromDate(effectiveOccurredAt),
        'userId': userId,
        'reason': reason,
        'note': note,
        'sourceChannelId': sourceChannelId,
        'stockAfter': nextStock,
      });
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
