import 'package:controle_estoque/features/inventory/domain/stock_movement.dart';
import 'package:controle_estoque/features/inventory/presentation/stock_count_movement_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets(
    'referência deixa o clique abrir a movimentação sem prévia do relatório',
    (tester) async {
      var openedMovement = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkWell(
              onTap: () => openedMovement = true,
              child: StockCountMovementReference(movement: _movement()),
            ),
          ),
        ),
      );
      expect(find.text('Contagem CT-0007'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      await tester.tap(find.text('Contagem CT-0007'));
      await tester.pumpAndSettle();
      expect(openedMovement, isTrue);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Relatório de contagem CT-0007'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
