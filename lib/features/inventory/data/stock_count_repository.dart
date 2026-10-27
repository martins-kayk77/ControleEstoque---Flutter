import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/firestore_serialization.dart';
import '../domain/stock_count.dart';

abstract class StockCountRepository {
  static const maxProducts = 200;
  Stream<List<StockCount>> watchCounts(String companyId);
  Future<StockCount?> findById(String companyId, String countId);
  Future<String> start({
    required String companyId,
    required List<String> productIds,
    required String userId,
    required String responsibleName,
    String note = '',
  });
  Future<void> saveProgress(StockCount count, List<StockCountItem> items);
  Future<void> cancel(StockCount count);
  Future<void> complete({
    required StockCount count,
    required List<StockCountItem> items,
    required String userId,
    required String userEmail,
  });
  Future<void> applyAdjustment({
    required StockCount count,
    required String userId,
    required String userEmail,
    required String responsibleName,
  });
}

final stockCountRepositoryProvider = Provider<StockCountRepository>(
  (ref) => FirestoreStockCountRepository(ref.watch(firebaseFirestoreProvider)),
);

final stockCountsProvider = StreamProvider.family<List<StockCount>, String>(
  (ref, companyId) =>
      ref.watch(stockCountRepositoryProvider).watchCounts(companyId),
);

class FirestoreStockCountRepository implements StockCountRepository {
  const FirestoreStockCountRepository(this.firestore);
  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> _collection(String companyId) =>
      firestore.collection(FirestorePaths.stockCounts(companyId));

  @override
  Stream<List<StockCount>> watchCounts(String companyId) =>
      _collection(companyId)
          .orderBy('startedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => decode(doc.id, companyId, doc.data()))
                .toList(),
          );

  @override
  Future<StockCount?> findById(String companyId, String countId) async {
    final snapshot = await _collection(companyId).doc(countId).get();
    final data = snapshot.data();
    return data == null ? null : decode(snapshot.id, companyId, data);
  }

  @override
  Future<String> start({
    required String companyId,
    required List<String> productIds,
    required String userId,
    required String responsibleName,
    String note = '',
  }) async {
    if (productIds.isEmpty ||
        productIds.length > StockCountRepository.maxProducts ||
        productIds.toSet().length != productIds.length) {
      throw ArgumentError(
        'Selecione de 1 a ${StockCountRepository.maxProducts} produtos distintos.',
      );
    }
    final countRef = _collection(companyId).doc();
    final companyRef = firestore.doc(FirestorePaths.company(companyId));
    await firestore.runTransaction((tx) async {
      final company = await tx.get(companyRef);
      if (!company.exists) throw StateError('Empresa não encontrada.');
      if (company.data()?['activeStockCountId'] != null) {
        throw StateError(
          'Já existe uma contagem em andamento. Continue ou cancele essa contagem.',
        );
      }
      final lastNumber = readInt(company.data()!, 'lastStockCountNumber');
      if (lastNumber < 0) {
        throw StateError('A numeração das contagens está inválida.');
      }
      final countNumber = lastNumber + 1;
      final items = <StockCountItem>[];
      for (final id in productIds) {
        final product = await tx.get(
          firestore.doc(FirestorePaths.product(companyId, id)),
        );
        final data = product.data();
        if (data == null || data['isActive'] == false) {
          throw StateError(
            'Um produto foi removido ou inativado. Atualize a lista.',
          );
        }
        items.add(
          StockCountItem(
            id: id,
            productId: id,
            productName: readString(data, 'name'),
            unit: readString(data, 'unit', fallback: 'un'),
            acquisitionCost: readDouble(data, 'acquisitionCost'),
            productUpdatedAt: readDateTime(data['updatedAt']),
            expectedQuantity: readInt(data, 'currentStock'),
            countedQuantity: null,
          ),
        );
      }
      tx.set(countRef, {
        'companyId': companyId,
        'number': countNumber,
        'status': StockCountStatus.inProgress.name,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': null,
        'responsibleUserId': userId,
        'responsibleName': responsibleName.trim(),
        'note': note.trim(),
        'itemsCount': items.length,
        'revision': 0,
        'items': items.map(encodeItem).toList(),
      });
      tx.update(companyRef, {
        'activeStockCountId': countRef.id,
        'lastStockCountNumber': countNumber,
      });
    });
    return countRef.id;
  }

  @override
  Future<void> saveProgress(
    StockCount count,
    List<StockCountItem> items,
  ) async {
    final ref = _collection(count.companyId).doc(count.id);
    await firestore.runTransaction((tx) async {
      final current = await tx.get(ref);
      _validateOpen(
        current,
        items,
        expectedRevision: count.revision,
        allowPending: true,
      );
      tx.update(ref, {
        'items': items.map(encodeItem).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': count.revision + 1,
      });
    });
  }

  @override
  Future<void> cancel(StockCount count) async {
    final ref = _collection(count.companyId).doc(count.id);
    final companyRef = firestore.doc(FirestorePaths.company(count.companyId));
    await firestore.runTransaction((tx) async {
      final current = await tx.get(ref);
      final company = await tx.get(companyRef);
      if (current.data()?['status'] != StockCountStatus.inProgress.name) {
        throw StateError('Esta contagem já foi encerrada.');
      }
      tx.update(ref, {
        'status': StockCountStatus.canceled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (company.data()?['activeStockCountId'] == count.id) {
        tx.update(companyRef, {'activeStockCountId': FieldValue.delete()});
      }
    });
  }

  @override
  Future<void> complete({
    required StockCount count,
    required List<StockCountItem> items,
    required String userId,
    required String userEmail,
  }) async {
    final countRef = _collection(count.companyId).doc(count.id);
    final companyRef = firestore.doc(FirestorePaths.company(count.companyId));
    await firestore.runTransaction((tx) async {
      final current = await tx.get(countRef);
      if (current.data()?['status'] == StockCountStatus.completed.name) return;
      _validateOpen(current, items, expectedRevision: count.revision);
      final company = await tx.get(companyRef);
      if (!company.exists) throw StateError('Empresa não encontrada.');
      final productRefs = [
        for (final item in items)
          firestore.doc(
            FirestorePaths.product(count.companyId, item.productId),
          ),
      ];
      for (var i = 0; i < items.length; i++) {
        final snapshot = await tx.get(productRefs[i]);
        final data = snapshot.data();
        final item = items[i];
        if (data == null ||
            data['isActive'] == false ||
            readInt(data, 'currentStock') != item.expectedQuantity ||
            readDateTime(data['updatedAt']) != item.productUpdatedAt) {
          throw StateError(
            'O estoque ou cadastro de ${item.productName} mudou durante a contagem. '
            'Salve suas anotações, cancele e inicie uma nova conferência. Nenhum ajuste foi aplicado.',
          );
        }
      }
      final companyUpdate = <String, dynamic>{
        'lastCompletedStockCountId': count.id,
      };
      if (company.data()?['activeStockCountId'] == count.id) {
        companyUpdate['activeStockCountId'] = FieldValue.delete();
      }
      tx.update(companyRef, companyUpdate);
      tx.update(countRef, {
        'status': StockCountStatus.completed.name,
        'items': items.map(encodeItem).toList(),
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'completedByUserId': userId,
        'revision': count.revision + 1,
      });
    });
  }

  @override
  Future<void> applyAdjustment({
    required StockCount count,
    required String userId,
    required String userEmail,
    required String responsibleName,
  }) async {
    final countRef = _collection(count.companyId).doc(count.id);
    final companyRef = firestore.doc(FirestorePaths.company(count.companyId));
    await firestore.runTransaction((tx) async {
      final stored = await tx.get(countRef);
      if (!stored.exists) throw StateError('Relatório não encontrado.');
      final report = decode(count.id, count.companyId, stored.data()!);
      if (report.status != StockCountStatus.completed) {
        throw StateError('Conclua a contagem antes de ajustar o estoque.');
      }
      if (report.stockAdjusted) return;
      validateItems(report.items, report.items);
      if (report.divergentItems == 0) {
        throw StateError(
          'Este relatório não possui divergências para ajustar.',
        );
      }
      final company = await tx.get(companyRef);
      if (!company.exists) throw StateError('Empresa não encontrada.');
      if (company.data()?['activeStockCountId'] != null) {
        throw StateError(
          'Existe uma contagem em andamento. Conclua ou cancele essa conferência antes de ajustar o estoque.',
        );
      }
      final latestCountId = company.data()?['lastCompletedStockCountId'];
      if (latestCountId != null && latestCountId != count.id) {
        throw StateError(
          'Existe uma contagem mais recente. Use o relatório mais recente para ajustar o estoque.',
        );
      }
      final items = report.items.where((item) => item.difference != 0).toList();
      final productRefs = [
        for (final item in items)
          firestore.doc(
            FirestorePaths.product(count.companyId, item.productId),
          ),
      ];
      for (var i = 0; i < items.length; i++) {
        final snapshot = await tx.get(productRefs[i]);
        final data = snapshot.data();
        final item = items[i];
        if (data == null ||
            data['isActive'] == false ||
            readInt(data, 'currentStock') != item.expectedQuantity ||
            readDateTime(data['updatedAt']) != item.productUpdatedAt) {
          throw StateError(
            'O estoque ou cadastro de ${item.productName} mudou desde a contagem. '
            'Faça uma nova conferência antes de ajustar. Nenhum ajuste foi aplicado.',
          );
        }
      }
      final storedNumber = readInt(
        company.data()!,
        'lastMovementNumber',
        fallback: 999,
      );
      final number = storedNumber < 999 ? 1000 : storedNumber + 1;
      final operationId = number.toString();
      tx.update(companyRef, {'lastMovementNumber': number});
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        tx.update(productRefs[i], {
          'currentStock': item.countedQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // Stable document IDs make retries and repeated submissions idempotent.
        tx.set(
          firestore
              .collection(FirestorePaths.movements(count.companyId))
              .doc('count_${count.id}_${item.productId}'),
          {
            'companyId': count.companyId,
            'productId': item.productId,
            'type': 'adjustment',
            'quantityDelta': item.difference,
            'occurredAt': FieldValue.serverTimestamp(),
            'operationId': operationId,
            'userId': userId,
            'userEmail': userEmail,
            'responsibleName': responsibleName.trim(),
            'operationReference': report.code == null
                ? 'Contagem'
                : 'Contagem ${report.code}',
            'stockCountId': count.id,
            'stockCountNumber': report.number,
            'reason': item.reason.isEmpty
                ? 'Conferência física de estoque'
                : item.reason,
            'note': report.code == null
                ? 'Ajuste gerado pela contagem.'
                : 'Ajuste gerado pela contagem ${report.code}.',
            'stockAfter': item.countedQuantity,
          },
        );
      }
      tx.update(countRef, {
        'operationId': operationId,
        'adjustedAt': FieldValue.serverTimestamp(),
        'adjustedByUserId': userId,
        'adjustedByName': responsibleName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static void _validateOpen(
    DocumentSnapshot<Map<String, dynamic>> current,
    List<StockCountItem> items, {
    required int expectedRevision,
    bool allowPending = false,
  }) {
    final data = current.data();
    if (data == null || data['status'] != StockCountStatus.inProgress.name) {
      throw StateError('Esta contagem já foi encerrada.');
    }
    if (readInt(data, 'revision') != expectedRevision) {
      throw StateError(
        'O progresso foi alterado em outra sessão. Recarregue o progresso antes de salvar.',
      );
    }
    final stored = decode(
      current.id,
      readString(data, 'companyId'),
      data,
    ).items;
    validateItems(stored, items, allowPending: allowPending);
  }

  static void validateItems(
    List<StockCountItem> stored,
    List<StockCountItem> items, {
    bool allowPending = false,
  }) {
    if (items.isEmpty ||
        items.length != stored.length ||
        items.length > StockCountRepository.maxProducts ||
        items.map((item) => item.productId).toSet().length != items.length) {
      throw ArgumentError(
        'Os produtos da contagem foram alterados. Reabra a contagem.',
      );
    }
    final originals = {for (final item in stored) item.productId: item};
    for (final item in items) {
      final original = originals[item.productId];
      if (original == null ||
          original.expectedQuantity != item.expectedQuantity ||
          original.productUpdatedAt != item.productUpdatedAt ||
          original.productName != item.productName ||
          original.unit != item.unit ||
          original.acquisitionCost != item.acquisitionCost) {
        throw ArgumentError(
          'A referência original da contagem não pode ser alterada.',
        );
      }
      if ((!allowPending && !item.isCounted) ||
          (item.countedQuantity != null &&
              (item.countedQuantity! < 0 ||
                  item.countedQuantity! > 1000000000))) {
        throw ArgumentError(
          'Informe a quantidade física de todos os produtos (zero quando não houver).',
        );
      }
    }
  }

  static Map<String, dynamic> encodeItem(StockCountItem item) => {
    'id': item.id,
    'productId': item.productId,
    'productName': item.productName,
    'unit': item.unit,
    'acquisitionCost': item.acquisitionCost,
    'productUpdatedAt': item.productUpdatedAt == null
        ? null
        : Timestamp.fromDate(item.productUpdatedAt!),
    'expectedQuantity': item.expectedQuantity,
    'countedQuantity': item.countedQuantity,
    'reason': item.reason,
  };

  static StockCount decode(
    String id,
    String companyId,
    Map<String, dynamic> data,
  ) => StockCount(
    id: id,
    companyId: companyId,
    startedAt: readDateTime(data['startedAt']),
    completedAt: data['completedAt'] == null
        ? null
        : readDateTime(data['completedAt']),
    status: StockCountStatus.values.firstWhere(
      (value) => value.name == data['status'],
      orElse: () => StockCountStatus.draft,
    ),
    responsibleUserId: data['responsibleUserId'] as String?,
    responsibleName: readString(data, 'responsibleName'),
    note: readString(data, 'note'),
    itemsCount: readInt(data, 'itemsCount'),
    revision: readInt(data, 'revision'),
    number: data['number'] is int && (data['number'] as int) > 0
        ? data['number'] as int
        : null,
    operationId: data['operationId'] as String?,
    adjustedAt: data['adjustedAt'] == null
        ? null
        : readDateTime(data['adjustedAt']),
    adjustedByUserId: data['adjustedByUserId'] as String?,
    adjustedByName: readString(data, 'adjustedByName'),
    items: (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return StockCountItem(
            id: readString(item, 'id'),
            productId: readString(item, 'productId'),
            productName: readString(item, 'productName'),
            unit: readString(item, 'unit', fallback: 'un'),
            acquisitionCost: readDouble(item, 'acquisitionCost'),
            productUpdatedAt: item['productUpdatedAt'] == null
                ? null
                : readDateTime(item['productUpdatedAt']),
            expectedQuantity: readInt(item, 'expectedQuantity'),
            countedQuantity: item['countedQuantity'] == null
                ? null
                : readInt(item, 'countedQuantity'),
            reason: readString(item, 'reason'),
          );
        })
        .toList(growable: false),
  );
}
