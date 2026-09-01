import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/firestore_serialization.dart';
import '../domain/stock_movement.dart';

abstract class StockMovementRepository {
  Stream<List<StockMovement>> watchRecentMovements(String companyId);
  Stream<List<StockMovement>> watchProductMovements(
    String companyId,
    String productId,
  );
  Future<void> add(StockMovement movement);
}

final stockMovementRepositoryProvider = Provider<StockMovementRepository>((
  ref,
) {
  return FirestoreStockMovementRepository(ref.watch(firebaseFirestoreProvider));
});

class FirestoreStockMovementRepository implements StockMovementRepository {
  const FirestoreStockMovementRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<StockMovement>> watchRecentMovements(String companyId) {
    return _collection(companyId)
        .orderBy('occurredAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromSnapshot).toList());
  }

  @override
  Stream<List<StockMovement>> watchProductMovements(
    String companyId,
    String productId,
  ) {
    return _collection(companyId)
        .where('productId', isEqualTo: productId)
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromSnapshot).toList());
  }

  @override
  Future<void> add(StockMovement movement) {
    return _collection(movement.companyId).doc(movement.id).set({
      'companyId': movement.companyId,
      'productId': movement.productId,
      'type': movement.type.code,
      'quantityDelta': movement.quantityDelta,
      'occurredAt': Timestamp.fromDate(movement.occurredAt),
      'userId': movement.userId,
      'reason': movement.reason,
      'note': movement.note,
      'sourceChannelId': movement.sourceChannelId,
      'stockAfter': movement.stockAfter,
    });
  }

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    return _firestore.collection(FirestorePaths.movements(companyId));
  }

  StockMovement _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return StockMovement(
      id: snapshot.id,
      companyId: readString(data, 'companyId'),
      productId: readString(data, 'productId'),
      type: stockMovementTypeFromCode(readString(data, 'type')),
      quantityDelta: readInt(data, 'quantityDelta'),
      occurredAt: readDateTime(data['occurredAt']),
      userId: _nullableString(data['userId']),
      reason: readString(data, 'reason'),
      note: readString(data, 'note'),
      sourceChannelId: _nullableString(data['sourceChannelId']),
      stockAfter: data['stockAfter'] is num
          ? (data['stockAfter'] as num).toInt()
          : null,
    );
  }

  String? _nullableString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }
}
