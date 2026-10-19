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

  static const _firstMovementNumber = 1000;
  static const _lastMovementNumberField = 'lastMovementNumber';

  final FirebaseFirestore _firestore;

  Future<void> applyMovement({
    required String companyId,
    required String productId,
    required StockMovementType type,
    required int quantityDelta,
    String? userId,
    String userEmail = '',
    String responsibleName = '',
    String operationReference = '',
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
      userEmail: userEmail,
      responsibleName: responsibleName,
      operationReference: operationReference,
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
    String userEmail = '',
    String responsibleName = '',
    String operationReference = '',
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
    final companyReference = _firestore.doc(FirestorePaths.company(companyId));
    final movementRefs = [
      for (var index = 0; index < items.length; index++)
        movementCollection.doc(),
    ];
    final effectiveOccurredAt = occurredAt ?? DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final companySnapshot = await transaction.get(companyReference);
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

      final operationNumber = _nextMovementNumber(companySnapshot);
      final operationId = operationNumber.toString();
      transaction.update(companyReference, {
        _lastMovementNumberField: operationNumber,
      });

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
          'userEmail': userEmail.trim(),
          'responsibleName': responsibleName.trim(),
          'operationReference': operationReference.trim(),
          'reason': reason,
          'note': note,
          'sourceChannelId': sourceChannelId,
          'stockAfter': nextStock,
          'reversalOfOperationId': null,
          'reversalOperationId': null,
          'reversedAt': null,
          'reversedByUserId': null,
          'reversedByResponsibleName': '',
          'reversalReason': '',
        });
      }
    });
  }

  Future<String> reverseOperation({
    required String companyId,
    required String operationId,
    required List<String> movementIds,
    required String responsibleName,
    required String reason,
    String? userId,
    String userEmail = '',
  }) async {
    final normalizedResponsible = responsibleName.trim();
    final normalizedReason = reason.trim();
    if (movementIds.isEmpty) {
      throw ArgumentError.value(
        movementIds,
        'movementIds',
        'A operação não possui itens para estornar.',
      );
    }
    if (normalizedResponsible.isEmpty) {
      throw ArgumentError.value(
        responsibleName,
        'responsibleName',
        'Informe o responsável pelo estorno.',
      );
    }
    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Informe o motivo do estorno.',
      );
    }

    final movementCollection = _firestore.collection(
      FirestorePaths.movements(companyId),
    );
    final companyReference = _firestore.doc(FirestorePaths.company(companyId));
    final originalRefs = [
      for (final movementId in movementIds) movementCollection.doc(movementId),
    ];
    final reversalRefs = [
      for (var index = 0; index < movementIds.length; index++)
        movementCollection.doc(),
    ];
    final reversedAt = DateTime.now();

    final reversalOperationId = await _firestore.runTransaction<String>((
      transaction,
    ) async {
      final companySnapshot = await transaction.get(companyReference);
      final originalSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final reference in originalRefs) {
        originalSnapshots.add(await transaction.get(reference));
      }

      final originalData = <Map<String, dynamic>>[];
      final productIds = <String>{};
      for (final snapshot in originalSnapshots) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw StateError('Movimentação original não encontrada.');
        }

        final storedOperationId = data['operationId'] as String?;
        if (storedOperationId != null &&
            storedOperationId.isNotEmpty &&
            storedOperationId != operationId) {
          throw StateError('Os itens não pertencem à mesma operação.');
        }
        if ((data['reversalOfOperationId'] as String?)?.isNotEmpty == true) {
          throw StateError('Uma operação de estorno não pode ser estornada.');
        }
        if ((data['reversalOperationId'] as String?)?.isNotEmpty == true) {
          throw StateError('Esta operação já foi estornada.');
        }

        final occurredAt = (data['occurredAt'] as Timestamp?)?.toDate();
        if (occurredAt == null) {
          throw StateError('A data da movimentação não está disponível.');
        }
        if (reversedAt.isAfter(occurredAt.add(const Duration(days: 7)))) {
          throw StateError('O prazo de 7 dias para estorno foi encerrado.');
        }

        final productId = data['productId'] as String?;
        if (productId == null || productId.isEmpty) {
          throw StateError('Produto da movimentação não encontrado.');
        }
        if (!productIds.add(productId)) {
          throw StateError('A operação possui produtos duplicados.');
        }
        originalData.add(data);
      }

      final productRefs = [
        for (final data in originalData)
          _firestore.doc(
            FirestorePaths.product(companyId, data['productId'] as String),
          ),
      ];
      final nextStocks = List<int>.filled(originalData.length, 0);

      for (var index = 0; index < productRefs.length; index++) {
        final productSnapshot = await transaction.get(productRefs[index]);
        final productData = productSnapshot.data();
        if (!productSnapshot.exists || productData == null) {
          throw StateError('Produto da movimentação não encontrado.');
        }

        final originalDelta =
            (originalData[index]['quantityDelta'] as num?)?.toInt() ?? 0;
        if (originalDelta == 0) {
          throw StateError(
            'A movimentação original possui quantidade inválida.',
          );
        }
        final currentStock =
            (productData['currentStock'] as num?)?.toInt() ?? 0;
        final nextStock = currentStock - originalDelta;
        if (nextStock < 0) {
          throw StateError(
            'O estoque atual não permite estornar esta entrada.',
          );
        }
        nextStocks[index] = nextStock;
      }

      final reversalOperationNumber = _nextMovementNumber(companySnapshot);
      final reversalOperationId = reversalOperationNumber.toString();
      final reversedTimestamp = Timestamp.fromDate(reversedAt);
      transaction.update(companyReference, {
        _lastMovementNumberField: reversalOperationNumber,
      });

      for (var index = 0; index < originalData.length; index++) {
        final data = originalData[index];
        final originalDelta = (data['quantityDelta'] as num).toInt();

        transaction.update(productRefs[index], {
          'currentStock': nextStocks[index],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(originalRefs[index], {
          'reversalOperationId': reversalOperationId,
          'reversedAt': reversedTimestamp,
          'reversedByUserId': userId,
          'reversedByResponsibleName': normalizedResponsible,
          'reversalReason': normalizedReason,
        });
        transaction.set(reversalRefs[index], {
          'companyId': companyId,
          'productId': data['productId'],
          'type': StockMovementType.reversal.code,
          'quantityDelta': -originalDelta,
          'occurredAt': reversedTimestamp,
          'operationId': reversalOperationId,
          'userId': userId,
          'userEmail': userEmail.trim(),
          'responsibleName': normalizedResponsible,
          'operationReference': data['operationReference'] ?? '',
          'reason': normalizedReason,
          'note': 'Estorno da operação $operationId.',
          'sourceChannelId': null,
          'stockAfter': nextStocks[index],
          'reversalOfOperationId': operationId,
          'reversalOperationId': null,
          'reversedAt': null,
          'reversedByUserId': null,
          'reversedByResponsibleName': '',
          'reversalReason': '',
        });
      }

      return reversalOperationId;
    });

    return reversalOperationId;
  }

  int _nextMovementNumber(
    DocumentSnapshot<Map<String, dynamic>> companySnapshot,
  ) {
    if (!companySnapshot.exists) {
      throw StateError('Empresa não encontrada.');
    }

    final storedNumber = companySnapshot.data()?[_lastMovementNumberField];
    final lastNumber = storedNumber is num
        ? storedNumber.toInt()
        : _firstMovementNumber - 1;
    return lastNumber < _firstMovementNumber
        ? _firstMovementNumber
        : lastNumber + 1;
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
