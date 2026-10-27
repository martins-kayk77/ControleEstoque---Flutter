import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:controle_estoque/features/inventory/data/stock_count_repository.dart';
import 'package:controle_estoque/features/inventory/domain/stock_count.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_firestore.dart';

void main() {
  late MemoryFirestore db;
  late FirestoreStockCountRepository repository;
  StockCount readCount(String id) => FirestoreStockCountRepository.decode(
    id,
    'c',
    db.documents['companies/c/stockCounts/$id']!,
  );
  Future<StockCount> start() async => readCount(
    await repository.start(
      companyId: 'c',
      productIds: ['a', 'b'],
      userId: 'u',
      responsibleName: 'Responsável',
    ),
  );
  List<Map<String, dynamic>> movements() => db.documents.entries
      .where((e) => e.key.startsWith('companies/c/movements/'))
      .map((e) => e.value)
      .toList();

  setUp(() {
    db = MemoryFirestore();
    db.documents['companies/c'] = {'lastMovementNumber': 999};
    for (final id in ['a', 'b']) {
      db.documents['companies/c/products/$id'] = {
        'name': 'Produto $id',
        'currentStock': 20,
        'unit': 'un',
        'acquisitionCost': 10.0,
        'isActive': true,
        'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 21)),
      };
    }
    repository = FirestoreStockCountRepository(db);
  });

  test(
    'numeração permanece no progresso e relatório, sem reutilizar cancelados',
    () async {
      final first = await start();
      expect(first.number, 1);
      expect(first.code, 'CT-0001');
      expect(db.documents['companies/c']!['lastStockCountNumber'], 1);

      final items = first.items.map((item) => item.withCount(20, '')).toList();
      final localProgress = first.withProgress(items, 1);
      expect(localProgress.number, first.number);
      expect(localProgress.code, first.code);
      await repository.saveProgress(first, items);
      final saved = readCount(first.id);
      expect(saved.number, 1);
      expect(saved.code, first.code);
      await repository.complete(
        count: saved,
        items: saved.items,
        userId: 'u',
        userEmail: '',
      );
      expect(readCount(first.id).code, first.code);
      expect(db.documents['companies/c']!['lastStockCountNumber'], 1);

      final canceled = await start();
      expect(canceled.code, 'CT-0002');
      await repository.cancel(canceled);
      expect(readCount(canceled.id).code, 'CT-0002');
      final next = await start();
      expect(next.number, 3);
      expect(next.code, 'CT-0003');
      expect(db.documents['companies/c']!['lastStockCountNumber'], 3);
    },
  );

  test('cada empresa mantém sua própria sequência de contagens', () async {
    db.documents['companies/other'] = {'lastMovementNumber': 999};
    db.documents['companies/other/products/a'] = Map<String, dynamic>.from(
      db.documents['companies/c/products/a']!,
    );
    final first = await start();
    await repository.cancel(first);
    final second = await start();
    final otherId = await repository.start(
      companyId: 'other',
      productIds: ['a'],
      userId: 'u2',
      responsibleName: 'Outra empresa',
    );
    final other = FirestoreStockCountRepository.decode(
      otherId,
      'other',
      db.documents['companies/other/stockCounts/$otherId']!,
    );
    expect(second.code, 'CT-0002');
    expect(other.code, 'CT-0001');
    expect(db.documents['companies/c']!['lastStockCountNumber'], 2);
    expect(db.documents['companies/other']!['lastStockCountNumber'], 1);
    expect(db.documents['companies/c']!['activeStockCountId'], second.id);
    expect(db.documents['companies/other']!['activeStockCountId'], other.id);
  });

  test(
    'falha ao iniciar não consome número nem deixa contagem parcial',
    () async {
      db.documents['companies/c']!['lastStockCountNumber'] = 7;
      await expectLater(
        repository.start(
          companyId: 'c',
          productIds: ['a', 'missing'],
          userId: 'u',
          responsibleName: 'Responsável',
        ),
        throwsStateError,
      );
      expect(db.documents['companies/c']!['lastStockCountNumber'], 7);
      expect(db.documents['companies/c']!['activeStockCountId'], isNull);
      expect(
        db.documents.keys.where(
          (path) => path.startsWith('companies/c/stockCounts/'),
        ),
        isEmpty,
      );
      final count = await start();
      expect(count.code, 'CT-0008');
      await expectLater(start(), throwsStateError);
      expect(db.documents['companies/c']!['lastStockCountNumber'], 8);
      expect(db.documents['companies/c']!['activeStockCountId'], count.id);
    },
  );

  test('código com mais de quatro dígitos não é truncado', () async {
    db.documents['companies/c']!['lastStockCountNumber'] = 9999;
    final count = await start();
    expect(count.number, 10000);
    expect(count.code, 'CT-10000');
  });

  test(
    'relatório legado sem número mantém vínculo e texto simples no ajuste',
    () async {
      final count = await start();
      db.documents['companies/c/stockCounts/${count.id}']!.remove('number');
      final legacy = readCount(count.id);
      expect(legacy.number, isNull);
      expect(legacy.code, isNull);
      expect(legacy.withProgress(legacy.items, 1).number, isNull);
      await repository.complete(
        count: legacy,
        items: legacy.items.map((item) => item.withCount(17, '')).toList(),
        userId: 'u',
        userEmail: '',
      );
      await repository.applyAdjustment(
        count: readCount(count.id),
        userId: 'u',
        userEmail: '',
        responsibleName: 'Responsável',
      );
      expect(readCount(count.id).number, isNull);
      expect(movements(), hasLength(2));
      for (final movement in movements()) {
        expect(movement['stockCountId'], count.id);
        expect(movement['stockCountNumber'], isNull);
        expect(movement['operationReference'], 'Contagem');
        expect(movement['note'], 'Ajuste gerado pela contagem.');
      }
    },
  );

  test(
    'inicia com quantidades pendentes e impede outra contagem simultânea',
    () async {
      final count = await start();
      expect(count.items.every((i) => !i.isCounted), isTrue);
      expect(count.items.first.expectedQuantity, 20);
      expect(count.items.first.productName, 'Produto a');
      await expectLater(start(), throwsStateError);
    },
  );

  test(
    'salva rascunho e bloqueia edição de uma revisão desatualizada',
    () async {
      final count = await start();
      final partial = [
        count.items[0].withCount(17, 'Conferido'),
        count.items[1],
      ];
      await repository.saveProgress(count, partial);
      final saved = readCount(count.id);
      expect(saved.countedItems, 1);
      expect(saved.items.first.reason, 'Conferido');
      expect(saved.revision, 1);
      await expectLater(
        repository.saveProgress(count, partial),
        throwsStateError,
      );
      await expectLater(
        repository.complete(
          count: saved,
          items: saved.items,
          userId: 'u',
          userEmail: 'u@example.com',
        ),
        throwsArgumentError,
      );
      expect(movements(), isEmpty);
    },
  );

  test(
    'conclui sem alterar estoque e aplica ajustes depois uma única vez',
    () async {
      final count = await start();
      final items = [
        count.items[0].withCount(17, 'Falta na conferência'),
        count.items[1].withCount(22, ''),
      ];
      await repository.complete(
        count: count,
        items: items,
        userId: 'u',
        userEmail: 'u@example.com',
      );
      expect(db.documents['companies/c/products/a']!['currentStock'], 20);
      expect(db.documents['companies/c/products/b']!['currentStock'], 20);
      final report = readCount(count.id);
      expect(report.status, StockCountStatus.completed);
      expect(report.missingUnits, 3);
      expect(report.surplusUnits, 2);
      expect(report.totalUnits, 39);
      expect(report.operationId, isNull);
      expect(report.stockAdjusted, isFalse);
      expect(movements(), isEmpty);
      expect(db.documents['companies/c']!['lastMovementNumber'], 999);
      final reportSnapshot = List.of(
        db.documents['companies/c/stockCounts/${count.id}']!['items'] as List,
      );
      await repository.applyAdjustment(
        count: report,
        userId: 'adjuster',
        userEmail: 'adjuster@example.com',
        responsibleName: 'Quem ajustou',
      );
      expect(db.documents['companies/c/products/a']!['currentStock'], 17);
      expect(db.documents['companies/c/products/b']!['currentStock'], 22);
      expect(readCount(count.id).stockAdjusted, isTrue);
      expect(readCount(count.id).adjustedByUserId, 'adjuster');
      expect(readCount(count.id).adjustedByName, 'Quem ajustou');
      expect(readCount(count.id).operationId, '1000');
      expect(
        db.documents['companies/c/stockCounts/${count.id}']!['items'],
        reportSnapshot,
      );
      expect(movements(), hasLength(2));
      expect(movements().map((m) => m['operationId']).toSet(), {'1000'});
      expect(movements().map((m) => m['quantityDelta']).toList(), [-3, 2]);
      for (final movement in movements()) {
        expect(movement['stockCountId'], count.id);
        expect(movement['stockCountNumber'], 1);
        expect(movement['operationReference'], 'Contagem CT-0001');
        expect(movement['note'], 'Ajuste gerado pela contagem CT-0001.');
      }
      expect(
        db.documents['companies/c']!.containsKey('activeStockCountId'),
        isFalse,
      );
      await repository.complete(
        count: count,
        items: items,
        userId: 'u',
        userEmail: 'u@example.com',
      );
      expect(movements(), hasLength(2));
      expect(db.documents['companies/c']!['lastMovementNumber'], 1000);
      await repository.applyAdjustment(
        count: report,
        userId: 'adjuster',
        userEmail: '',
        responsibleName: 'Quem ajustou',
      );
      expect(movements(), hasLength(2));
      expect(db.documents['companies/c']!['lastMovementNumber'], 1000);
      db.documents['companies/c/products/a']!['name'] = 'Nome alterado';
      expect(readCount(count.id).items.first.productName, 'Produto a');
    },
  );

  test('movimentação concorrente impede qualquer ajuste parcial', () async {
    final count = await start();
    db.documents['companies/c/products/b']!['currentStock'] = 18;
    final items = count.items.map((i) => i.withCount(17, '')).toList();
    await expectLater(
      repository.complete(
        count: count,
        items: items,
        userId: 'u',
        userEmail: 'u@example.com',
      ),
      throwsStateError,
    );
    expect(db.documents['companies/c/products/a']!['currentStock'], 20);
    expect(db.documents['companies/c/products/b']!['currentStock'], 18);
    expect(movements(), isEmpty);
    expect(readCount(count.id).isOpen, isTrue);
    await repository.cancel(count);
    expect(readCount(count.id).status, StockCountStatus.canceled);
    expect((await start()).isOpen, isTrue);
  });

  test(
    'alteração após gerar relatório impede qualquer ajuste parcial',
    () async {
      final count = await start();
      await repository.complete(
        count: count,
        items: count.items.map((i) => i.withCount(17, '')).toList(),
        userId: 'u',
        userEmail: '',
      );
      db.documents['companies/c/products/b']!['currentStock'] = 18;
      await expectLater(
        repository.applyAdjustment(
          count: readCount(count.id),
          userId: 'u',
          userEmail: '',
          responsibleName: 'Responsável',
        ),
        throwsStateError,
      );
      expect(db.documents['companies/c/products/a']!['currentStock'], 20);
      expect(db.documents['companies/c/products/b']!['currentStock'], 18);
      expect(movements(), isEmpty);
      expect(readCount(count.id).stockAdjusted, isFalse);
      expect(readCount(count.id).status, StockCountStatus.completed);
    },
  );

  test('relatório antigo já ajustado não reaplica diferenças', () async {
    final count = await start();
    await repository.complete(
      count: count,
      items: count.items.map((i) => i.withCount(17, '')).toList(),
      userId: 'u',
      userEmail: '',
    );
    db.documents['companies/c/stockCounts/${count.id}']!['operationId'] =
        '1000';
    final legacy = readCount(count.id);
    expect(legacy.adjustedAt, isNull);
    expect(legacy.stockAdjusted, isTrue);
    await repository.applyAdjustment(
      count: legacy,
      userId: 'u',
      userEmail: '',
      responsibleName: 'Responsável',
    );
    expect(movements(), isEmpty);
    expect(db.documents['companies/c/products/a']!['currentStock'], 20);
  });

  test(
    'contagem em andamento ou relatório mais recente bloqueiam ajuste antigo',
    () async {
      final first = await start();
      await repository.complete(
        count: first,
        items: first.items.map((i) => i.withCount(17, '')).toList(),
        userId: 'u',
        userEmail: '',
      );
      final newer = await start();
      await expectLater(
        repository.applyAdjustment(
          count: readCount(first.id),
          userId: 'u',
          userEmail: '',
          responsibleName: 'Responsável',
        ),
        throwsStateError,
      );
      await repository.complete(
        count: newer,
        items: newer.items.map((i) => i.withCount(18, '')).toList(),
        userId: 'u',
        userEmail: '',
      );
      await expectLater(
        repository.applyAdjustment(
          count: readCount(first.id),
          userId: 'u',
          userEmail: '',
          responsibleName: 'Responsável',
        ),
        throwsStateError,
      );
      expect(movements(), isEmpty);
      await repository.applyAdjustment(
        count: readCount(newer.id),
        userId: 'u',
        userEmail: '',
        responsibleName: 'Responsável',
      );
      expect(db.documents['companies/c/products/a']!['currentStock'], 18);
    },
  );

  test(
    'detecta alteração mesmo que o saldo tenha voltado ao mesmo valor',
    () async {
      final count = await start();
      db.documents['companies/c/products/a']!['updatedAt'] = Timestamp.fromDate(
        DateTime(2026, 10, 22),
      );
      await expectLater(
        repository.complete(
          count: count,
          items: count.items.map((i) => i.withCount(20, '')).toList(),
          userId: 'u',
          userEmail: '',
        ),
        throwsStateError,
      );
      expect(movements(), isEmpty);
    },
  );

  test(
    'sem divergências gera relatório sem movimentações artificiais',
    () async {
      final count = await start();
      await repository.complete(
        count: count,
        items: count.items.map((i) => i.withCount(20, '')).toList(),
        userId: 'u',
        userEmail: '',
      );
      expect(readCount(count.id).status, StockCountStatus.completed);
      expect(readCount(count.id).operationId, isNull);
      expect(movements(), isEmpty);
      expect(db.documents['companies/c']!['lastMovementNumber'], 999);
    },
  );

  test(
    'zero é contado; valores negativos, duplicação e referência adulterada são rejeitados',
    () async {
      final count = await start();
      final zero = count.items.map((i) => i.withCount(0, '')).toList();
      expect(
        () => FirestoreStockCountRepository.validateItems(count.items, zero),
        returnsNormally,
      );
      expect(
        () => FirestoreStockCountRepository.validateItems(
          count.items,
          count.items.map((i) => i.withCount(-1, '')).toList(),
        ),
        throwsArgumentError,
      );
      expect(
        () => FirestoreStockCountRepository.validateItems(count.items, [
          zero[0],
          zero[0],
        ]),
        throwsArgumentError,
      );
      final forged = StockCountItem(
        id: 'a',
        productId: 'a',
        expectedQuantity: 99,
        countedQuantity: 0,
        productName: 'Produto a',
      );
      expect(
        () => FirestoreStockCountRepository.validateItems(count.items, [
          forged,
          zero[1],
        ]),
        throwsArgumentError,
      );
    },
  );
}
