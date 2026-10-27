import 'dart:async';

import 'package:controle_estoque/features/auth/application/auth_state.dart';
import 'package:controle_estoque/features/inventory/data/stock_count_repository.dart';
import 'package:controle_estoque/features/inventory/domain/stock_count.dart';
import 'package:controle_estoque/features/inventory/domain/stock_movement.dart';
import 'package:controle_estoque/features/inventory/presentation/stock_count_movement_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountRepository extends Fake implements StockCountRepository {
  final result = Completer<StockCount?>();
  final lookups = <(String, String)>[];

  @override
  Future<StockCount?> findById(String companyId, String countId) {
    lookups.add((companyId, countId));
    return result.future;
  }

  @override
  Stream<List<StockCount>> watchCounts(String companyId) => Stream.value([]);
}

StockMovement _movement({
  String? countId = 'saved-count',
  int? number = 7,
  String reference = 'Contagem CT-0007',
  String note = 'Ajuste gerado pela contagem CT-0007.',
}) => StockMovement(
  id: 'movement',
  companyId: 'company',
  productId: 'product',
  type: StockMovementType.adjustment,
  quantityDelta: -1,
  occurredAt: DateTime(2026, 10, 22),
  stockCountId: countId,
  stockCountNumber: number,
  operationReference: reference,
  note: note,
);

void main() {
  test('código curto é preservado e ID interno antigo é ocultado', () {
    final numbered = _movement();
    expect(stockCountMovementReference(numbered), 'Contagem CT-0007');
    expect(
      stockCountMovementNote(numbered),
      'Ajuste gerado pela contagem CT-0007.',
    );
    const id = '4PabRWQalanw4axETh50';
    final legacy = _movement(
      countId: null,
      number: null,
      reference: 'Contagem $id',
      note: 'Ajuste gerado pela contagem $id.',
    );
    expect(stockCountMovementId(legacy), id);
    expect(stockCountMovementReference(legacy), 'Contagem');
    expect(stockCountMovementNote(legacy), 'Ajuste gerado pela contagem.');
  });

  test('referências manuais e notas personalizadas permanecem intactas', () {
    final manual = _movement(
      countId: null,
      number: null,
      reference: 'Contagem CT-0009',
      note: 'Revisão manual.',
    );
    expect(stockCountMovementId(manual), isNull);
    expect(stockCountMovementReference(manual), 'Contagem CT-0009');
    expect(stockCountMovementNote(manual), 'Revisão manual.');
    final customized = _movement(
      reference: 'Conferência semanal',
      note: 'Ajuste revisado pela equipe.',
    );
    expect(stockCountMovementReference(customized), 'Conferência semanal');
    expect(stockCountMovementNote(customized), 'Ajuste revisado pela equipe.');
  });

  Future<void> mount(WidgetTester tester, _CountRepository repository) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockCountRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StockCountMovementReference(movement: _movement()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('link consulta empresa correta, carrega e abre relatório', (
    tester,
  ) async {
    final repository = _CountRepository();
    await mount(tester, repository);
    expect(repository.lookups, isEmpty);
    await tester.tap(find.text('Contagem CT-0007'));
    await tester.pump();
    expect(repository.lookups, [('company', 'saved-count')]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.result.complete(
      StockCount(
        id: 'saved-count',
        companyId: 'company',
        number: 7,
        startedAt: DateTime(2026, 10, 22),
        status: StockCountStatus.completed,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Relatório de contagem CT-0007'), findsOneWidget);
    expect(find.textContaining('saved-count'), findsNothing);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ausência de relatório informa usuário sem expor ID', (
    tester,
  ) async {
    final repository = _CountRepository();
    await mount(tester, repository);
    await tester.tap(find.text('Contagem CT-0007'));
    repository.result.complete(null);
    await tester.pumpAndSettle();
    expect(
      find.text('O relatório desta contagem não foi encontrado.'),
      findsOneWidget,
    );
    expect(find.textContaining('saved-count'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('falha de consulta informa usuário e libera tentativa', (
    tester,
  ) async {
    final repository = _CountRepository();
    await mount(tester, repository);
    await tester.tap(find.text('Contagem CT-0007'));
    repository.result.completeError(
      StateError('internal technical identifier'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível abrir o relatório. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.textContaining('technical identifier'), findsNothing);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNotNull,
    );
  });
}
