import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:controle_estoque/app/theme/app_theme.dart';
import 'package:controle_estoque/features/auth/application/auth_state.dart';
import 'package:controle_estoque/features/auth/data/auth_repository.dart';
import 'package:controle_estoque/features/auth/domain/app_user.dart';
import 'package:controle_estoque/features/inventory/data/stock_count_repository.dart';
import 'package:controle_estoque/features/inventory/domain/product.dart';
import 'package:controle_estoque/features/inventory/domain/stock_count.dart';
import 'package:controle_estoque/features/inventory/presentation/stock_count_report.dart';
import 'package:controle_estoque/features/inventory/presentation/stock_count_comparison_panel.dart';
import 'package:controle_estoque/screens/tela_contagens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../support/memory_firestore.dart';

class ScreenCountRepository extends FirestoreStockCountRepository {
  ScreenCountRepository(this.db) : super(db);
  final MemoryFirestore db;
  bool failProgressSave = false;
  final changes = StreamController<void>.broadcast();
  List<StockCount> _reports(String company) => db.documents.entries
      .where((entry) => entry.key.startsWith('companies/$company/stockCounts/'))
      .map(
        (entry) => FirestoreStockCountRepository.decode(
          entry.key.split('/').last,
          company,
          entry.value,
        ),
      )
      .toList();
  @override
  Stream<List<StockCount>> watchCounts(String companyId) async* {
    yield _reports(companyId);
    yield* changes.stream.map((_) => _reports(companyId));
  }

  @override
  Future<String> start({
    required String companyId,
    required List<String> productIds,
    required String userId,
    required String responsibleName,
    String note = '',
  }) async {
    final id = await super.start(
      companyId: companyId,
      productIds: productIds,
      userId: userId,
      responsibleName: responsibleName,
      note: note,
    );
    changes.add(null);
    return id;
  }

  @override
  Future<void> saveProgress(
    StockCount count,
    List<StockCountItem> items,
  ) async {
    if (failProgressSave) throw StateError('Falha ao salvar progresso.');
    await super.saveProgress(count, items);
    changes.add(null);
  }

  @override
  Future<void> complete({
    required StockCount count,
    required List<StockCountItem> items,
    required String userId,
    required String userEmail,
  }) async {
    await super.complete(
      count: count,
      items: items,
      userId: userId,
      userEmail: userEmail,
    );
    changes.add(null);
  }

  @override
  Future<void> applyAdjustment({
    required StockCount count,
    required String userId,
    required String userEmail,
    required String responsibleName,
  }) async {
    await super.applyAdjustment(
      count: count,
      userId: userId,
      userEmail: userEmail,
      responsibleName: responsibleName,
    );
    changes.add(null);
  }
}

class _CountPasswordAuthRepository extends Fake implements AuthRepository {
  int attempts = 0;
  Completer<void>? verification;

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    attempts++;
    if (password != 'senha correta') {
      throw FirebaseAuthException(code: 'wrong-password');
    }
    await verification?.future;
  }
}

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'ajuste exige confirmação e senha válida em $width pixels',
      (tester) => _exerciseAdjustmentAuthorization(tester, width),
    );
  }

  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'retoma progresso pelo resumo sem alterar estoque em $width pixels',
      (tester) => _exerciseSavedProgress(tester, width),
    );
  }

  testWidgets(
    'falha ao salvar mantém a contagem aberta e o preenchimento',
    (tester) => _exerciseSavedProgress(tester, 390, failSave: true),
  );

  testWidgets(
    'conferência salva relatório e ajusta somente pela ação na visualização',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = MemoryFirestore();
      db.documents['companies/c'] = {'lastMovementNumber': 999};
      final now = DateTime(2026, 10, 21);
      final products = [
        for (final id in ['a', 'b'])
          Product(
            id: id,
            companyId: 'c',
            name: 'Produto $id',
            currentStock: 20,
            createdAt: now,
            updatedAt: now,
          ),
      ];
      for (final product in products) {
        db.documents['companies/c/products/${product.id}'] = {
          'name': product.name,
          'currentStock': 20,
          'isActive': true,
          'updatedAt': Timestamp.fromDate(now),
          'unit': 'un',
        };
      }
      final repository = ScreenCountRepository(db);
      final authRepository = _CountPasswordAuthRepository();
      addTearDown(repository.changes.close);
      Widget app() => ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AppUser(
                id: 'u',
                email: 'u@example.com',
                displayName: 'Pessoa responsável',
                companyIds: ['c'],
                activeCompanyId: 'c',
              ),
            ),
          ),
          countProductsProvider(
            'c',
          ).overrideWith((ref) => Stream.value(products)),
          stockCountRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: StockCountsPage()),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Nenhum relatório salvo. Conclua a primeira contagem para começar o histórico.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Iniciar contagem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Começar conferência'));
      await tester.pumpAndSettle();
      expect(find.text('Contagem CT-0001 em andamento'), findsOneWidget);
      final finish = find.widgetWithText(
        FilledButton,
        'Concluir e gerar relatório',
      );
      expect(tester.widget<FilledButton>(finish).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('count-quantity-a')),
        '17',
      );
      await tester.ensureVisible(find.text('Salvar progresso'));
      await tester.tap(find.text('Salvar progresso'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('count-quantity-a')), findsNothing);
      expect(find.text('Continuar contagem'), findsOneWidget);
      final stored = db.documents.entries.firstWhere(
        (e) => e.key.contains('/stockCounts/'),
      );
      expect((stored.value['items'] as List).first['countedQuantity'], 17);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('count-quantity-a')), findsNothing);
      await tester.ensureVisible(find.text('Continuar contagem'));
      await tester.tap(find.text('Continuar contagem'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('count-quantity-a')),
            )
            .controller!
            .text,
        '17',
      );
      expect(tester.widget<FilledButton>(finish).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('count-quantity-b')),
        '0',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar conclusão'));
      await tester.pumpAndSettle();
      expect(db.documents['companies/c/products/a']!['currentStock'], 20);
      expect(db.documents['companies/c/products/b']!['currentStock'], 20);
      expect(find.text('Contagem CT-0001 em andamento'), findsNothing);
      expect(find.text('Histórico de relatórios'), findsOneWidget);
      final historySearch = find.widgetWithText(
        TextField,
        'Buscar por código, data, responsável ou observação',
      );
      await tester.ensureVisible(historySearch);
      await tester.enterText(historySearch, 'CT-9999');
      await tester.pumpAndSettle();
      expect(find.text('Ver relatório'), findsNothing);
      await tester.enterText(historySearch, 'ct-0001');
      await tester.pumpAndSettle();
      expect(find.text('Ver relatório'), findsOneWidget);
      await tester.ensureVisible(find.text('Ver relatório'));
      await tester.tap(find.text('Ver relatório'));
      await tester.pumpAndSettle();
      expect(find.text('Relatório de contagem CT-0001'), findsOneWidget);
      expect(find.text('23 faltas'), findsOneWidget);
      await tester.tap(find.text('Ajustar estoque'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(db.documents['companies/c/products/a']!['currentStock'], 20);
      await tester.tap(find.text('Ajustar estoque'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Confirme sua senha'), findsOneWidget);
      expect(db.documents['companies/c/products/a']!['currentStock'], 20);
      await tester.enterText(find.byType(TextFormField), 'senha correta');
      await tester.tap(find.text('Aplicar ajuste'));
      await tester.pumpAndSettle();
      expect(authRepository.attempts, 1);
      expect(db.documents['companies/c/products/a']!['currentStock'], 17);
      expect(db.documents['companies/c/products/b']!['currentStock'], 0);
      expect(find.text('Estoque ajustado'), findsOneWidget);
      expect(find.text('Ajustar estoque'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final alreadyAdjusted in [false, true]) {
    testWidgets(
      'relatório longo mantém rodapé e reconhece ajuste anterior: $alreadyAdjusted',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final report = StockCount(
          id: 'report',
          number: alreadyAdjusted ? null : 7,
          companyId: 'c',
          startedAt: DateTime(2026, 10, 22),
          completedAt: DateTime(2026, 10, 22, 12),
          status: StockCountStatus.completed,
          responsibleName: 'Pessoa responsável',
          operationId: alreadyAdjusted ? '1005' : null,
          items: [
            for (var i = 0; i < 21; i++)
              StockCountItem(
                id: '$i',
                productId: '$i',
                productName: 'Produto $i',
                expectedQuantity: 20,
                countedQuantity: 19,
              ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              stockCountsProvider(
                'c',
              ).overrideWith((ref) => Stream.value([report])),
              authStateProvider.overrideWith(
                (ref) => Stream.value(
                  const AppUser(
                    id: 'u',
                    email: 'u@example.com',
                    companyIds: ['c'],
                    activeCompanyId: 'c',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showStockCountReport(context, report),
                    child: const Text('Abrir relatório'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abrir relatório'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            alreadyAdjusted
                ? 'Relatório de contagem'
                : 'Relatório de contagem CT-0007',
          ),
          findsOneWidget,
        );
        if (alreadyAdjusted) {
          expect(find.text('Estoque ajustado'), findsOneWidget);
          expect(find.text('Ajustar estoque'), findsNothing);
        } else {
          final button = find.text('Ajustar estoque');
          final originalPosition = tester.getRect(button);
          expect(originalPosition.bottom, lessThan(844));
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -1000),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(button), originalPosition);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [390.0, 1280.0]) {
    testWidgets('comparação mostra diferenças e incluídos em $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      StockCountItem item(String id, int expected, int found) => StockCountItem(
        id: id,
        productId: id,
        productName: 'Produto $id',
        expectedQuantity: expected,
        countedQuantity: found,
      );
      final before = StockCount(
        id: 'before',
        number: 1,
        companyId: 'c',
        startedAt: DateTime(2026, 10, 1),
        completedAt: DateTime(2026, 10, 1, 12),
        status: StockCountStatus.completed,
        items: [item('a', 20, 20), item('b', 10, 10)],
      );
      final after = StockCount(
        id: 'after',
        number: 2,
        companyId: 'c',
        startedAt: DateTime(2026, 10, 8),
        completedAt: DateTime(2026, 10, 8, 12),
        status: StockCountStatus.completed,
        items: [item('a', 17, 15), item('b', 10, 10), item('c', 4, 4)],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StockCountComparisonPanel(
                reports: [after, before],
                sourceReportId: after.id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Selecione o segundo relatório para visualizar as diferenças.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(countTitle(before)).last);
      await tester.pumpAndSettle();
      expect(find.text(countTitle(before)), findsWidgets);
      expect(find.text(countTitle(after)), findsWidgets);
      expect(find.text('Produto b'), findsNothing);
      expect(find.text('Incluído na contagem'), findsOneWidget);
      expect(find.text('Variação física: -5 • Registrada: -3'), findsOneWidget);
      await tester.tap(find.text('Mostrar apenas diferenças'));
      await tester.pumpAndSettle();
      expect(find.text('Produto b'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _exerciseAdjustmentAuthorization(
  WidgetTester tester,
  double width,
) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = MemoryFirestore();
  db.documents['companies/c'] = {'lastMovementNumber': 999};
  db.documents['companies/c/products/a'] = {
    'name': 'Produto a',
    'currentStock': 20,
    'isActive': true,
    'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 22)),
    'unit': 'un',
  };
  final repository = ScreenCountRepository(db);
  final authRepository = _CountPasswordAuthRepository();
  addTearDown(repository.changes.close);
  final countId = await repository.start(
    companyId: 'c',
    productIds: ['a'],
    userId: 'u',
    responsibleName: 'Pessoa responsável',
  );
  StockCount storedCount() => FirestoreStockCountRepository.decode(
    countId,
    'c',
    db.documents['companies/c/stockCounts/$countId']!,
  );
  final count = storedCount();
  await repository.complete(
    count: count,
    items: [count.items.single.withCount(17, '')],
    userId: 'u',
    userEmail: 'u@example.com',
  );
  void expectUnchanged() {
    expect(db.documents['companies/c/products/a']!['currentStock'], 20);
    expect(storedCount().stockAdjusted, isFalse);
    expect(
      db.documents.keys.where(
        (path) => path.startsWith('companies/c/movements/'),
      ),
      isEmpty,
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        stockCountRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(authRepository),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(
              id: 'u',
              email: 'u@example.com',
              displayName: 'Pessoa responsável',
              companyIds: ['c'],
              activeCompanyId: 'c',
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: width < 650 ? AppTheme.light() : AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showStockCountReport(context, storedCount()),
              child: const Text('Abrir relatório'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abrir relatório'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajustar estoque'));
  await tester.pumpAndSettle();
  expect(find.text('Ajustar estoque?'), findsOneWidget);
  expect(find.text('Confirme sua senha'), findsNothing);
  expect(authRepository.attempts, 0);
  expectUnchanged();
  await tester.tap(find.text('Revisar'));
  await tester.pumpAndSettle();
  expect(authRepository.attempts, 0);
  expectUnchanged();

  await tester.tap(find.text('Ajustar estoque'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  expect(find.text('Confirme sua senha'), findsOneWidget);
  expect(authRepository.attempts, 0);
  expectUnchanged();
  final password = find.byType(TextFormField);
  final passwordInput = find.descendant(
    of: password,
    matching: find.byType(TextField),
  );
  expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
  await tester.tap(find.text('Aplicar ajuste'));
  await tester.pumpAndSettle();
  expect(find.text('Informe sua senha.'), findsOneWidget);
  expect(authRepository.attempts, 0);
  await tester.tap(find.byTooltip('Mostrar senha'));
  await tester.pumpAndSettle();
  expect(tester.widget<TextField>(passwordInput).obscureText, isFalse);
  await tester.tap(find.byTooltip('Ocultar senha'));
  await tester.pumpAndSettle();
  expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
  await tester.enterText(password, 'senha incorreta');
  await tester.tap(find.text('Aplicar ajuste'));
  await tester.pumpAndSettle();
  expect(
    find.text('Senha incorreta. Confira e tente novamente.'),
    findsOneWidget,
  );
  expect(find.text('Confirme sua senha'), findsOneWidget);
  expect(authRepository.attempts, 1);
  expectUnchanged();
  await tester.tap(find.text('Cancelar'));
  await tester.pumpAndSettle();
  expect(find.text('Confirme sua senha'), findsNothing);
  expectUnchanged();

  await tester.tap(find.text('Ajustar estoque'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  expect(tester.widget<TextFormField>(password).controller!.text, isEmpty);
  final verification = Completer<void>();
  authRepository.verification = verification;
  await tester.enterText(password, 'senha correta');
  await tester.tap(find.text('Aplicar ajuste'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(authRepository.attempts, 2);
  expect(tester.widget<TextFormField>(password).enabled, isFalse);
  expect(
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
        .onPressed,
    isNull,
  );
  expect(
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Ajustando estoque…'),
        )
        .onPressed,
    isNull,
  );
  expectUnchanged();
  verification.complete();
  await tester.pumpAndSettle();
  expect(find.text('Confirme sua senha'), findsNothing);
  expect(find.text('Estoque ajustado'), findsOneWidget);
  expect(find.text('Ajustar estoque'), findsNothing);
  expect(db.documents['companies/c/products/a']!['currentStock'], 17);
  expect(storedCount().stockAdjusted, isTrue);
  expect(storedCount().adjustedByUserId, 'u');
  expect(
    db.documents.keys.where(
      (path) => path.startsWith('companies/c/movements/'),
    ),
    hasLength(1),
  );
  expect(tester.takeException(), isNull);
}

Future<void> _exerciseSavedProgress(
  WidgetTester tester,
  double width, {
  bool failSave = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = MemoryFirestore();
  db.documents['companies/c'] = {'lastMovementNumber': 999};
  final now = DateTime(2026, 10, 22);
  final products = [
    for (final id in ['a', 'b'])
      Product(
        id: id,
        companyId: 'c',
        name: 'Produto $id',
        currentStock: 20,
        createdAt: now,
        updatedAt: now,
      ),
  ];
  for (final product in products) {
    db.documents['companies/c/products/${product.id}'] = {
      'name': product.name,
      'currentStock': 20,
      'isActive': true,
      'updatedAt': Timestamp.fromDate(now),
      'unit': 'un',
    };
  }
  final repository = ScreenCountRepository(db);
  addTearDown(repository.changes.close);
  final countId = await repository.start(
    companyId: 'c',
    productIds: ['a', 'b'],
    userId: 'u',
    responsibleName: 'Pessoa responsável',
  );
  StockCount savedCount() => FirestoreStockCountRepository.decode(
    countId,
    'c',
    db.documents['companies/c/stockCounts/$countId']!,
  );
  final count = savedCount();
  await repository.saveProgress(count, [
    count.items[0].withCount(17, 'Conferência parcial'),
    count.items[1],
  ]);
  repository.failProgressSave = failSave;
  Widget app() => ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          const AppUser(
            id: 'u',
            email: 'u@example.com',
            displayName: 'Pessoa responsável',
            companyIds: ['c'],
            activeCompanyId: 'c',
          ),
        ),
      ),
      countProductsProvider('c').overrideWith((ref) => Stream.value(products)),
      stockCountRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: StockCountsPage()),
    ),
  );
  final firstQuantity = find.byKey(const ValueKey('count-quantity-a'));
  final secondQuantity = find.byKey(const ValueKey('count-quantity-b'));
  await tester.pumpWidget(app());
  await tester.pumpAndSettle();
  expect(find.text('Contagem CT-0001 em andamento'), findsOneWidget);
  expect(find.textContaining('1 de 2'), findsOneWidget);
  expect(firstQuantity, findsNothing);
  expect(secondQuantity, findsNothing);
  expect(find.text('Localizar produto na contagem'), findsNothing);
  expect(find.text('Histórico de relatórios'), findsOneWidget);
  final summary = find.byKey(ValueKey('count-summary-$countId'));
  await tester.ensureVisible(summary);
  await tester.tapAt(tester.getTopLeft(summary) + const Offset(20, 20));
  await tester.pumpAndSettle();
  expect(tester.widget<TextFormField>(firstQuantity).controller!.text, '17');
  expect(tester.widget<TextFormField>(secondQuantity).controller!.text, '');
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.controller?.text == 'Conferência parcial',
    ),
    findsOneWidget,
  );
  await tester.enterText(secondQuantity, '0');
  await tester.ensureVisible(find.text('Salvar progresso'));
  await tester.tap(find.text('Salvar progresso'));
  await tester.pumpAndSettle();
  if (failSave) {
    expect(find.text('Falha ao salvar progresso.'), findsOneWidget);
    expect(find.text('Continuar contagem'), findsNothing);
    expect(tester.widget<TextFormField>(firstQuantity).controller!.text, '17');
    expect(tester.widget<TextFormField>(secondQuantity).controller!.text, '0');
    expect(savedCount().items[1].countedQuantity, isNull);
  } else {
    expect(firstQuantity, findsNothing);
    expect(secondQuantity, findsNothing);
    expect(find.textContaining('2 de 2'), findsOneWidget);
    expect(find.text('Continuar contagem'), findsOneWidget);
    await tester.ensureVisible(find.text('Continuar contagem'));
    await tester.tap(find.text('Continuar contagem'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(firstQuantity).controller!.text, '17');
    expect(tester.widget<TextFormField>(secondQuantity).controller!.text, '0');
    await tester.ensureVisible(find.text('Salvar progresso'));
    await tester.tap(find.text('Salvar progresso'));
    await tester.pumpAndSettle();
    expect(firstQuantity, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(firstQuantity, findsNothing);
    await tester.ensureVisible(find.text('Continuar contagem'));
    await tester.tap(find.text('Continuar contagem'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(firstQuantity).controller!.text, '17');
    expect(tester.widget<TextFormField>(secondQuantity).controller!.text, '0');
  }
  expect(db.documents['companies/c/products/a']!['currentStock'], 20);
  expect(db.documents['companies/c/products/b']!['currentStock'], 20);
  expect(
    db.documents.keys.where((key) => key.startsWith('companies/c/movements/')),
    isEmpty,
  );
  expect(tester.takeException(), isNull);
}
