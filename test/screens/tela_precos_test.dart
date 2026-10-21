import 'package:controle_estoque/app/theme/app_theme.dart';
import 'package:controle_estoque/screens/tela_precos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('calcula o preço de venda e renderiza em tela compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pricingProductsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: PricingPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('pricing-mode')),
        matching: find.text('Calcular preço'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('pricing-profit-unit')),
        matching: find.text('%'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pricing-product-cost')), '50');
    await tester.enterText(
      find.byKey(const Key('pricing-additional-costs')),
      '4',
    );
    await tester.enterText(find.byKey(const Key('pricing-fixed-fee')), '0');
    await tester.enterText(
      find.byKey(const Key('pricing-percentage-fee')),
      '15',
    );
    await tester.enterText(
      find.byKey(const Key('pricing-desired-profit')),
      '25',
    );
    await tester.ensureVisible(find.text('Calcular'));
    await tester.tap(find.text('Calcular'));
    await tester.pumpAndSettle();

    expect(find.text('Preço de venda recomendado'), findsOneWidget);
    expect(find.text('R\$ 90,00'), findsWidgets);

    await tester.ensureVisible(find.text('Limpar'));
    await tester.tap(find.text('Limpar'));
    await tester.ensureVisible(find.byKey(const Key('pricing-mode')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('pricing-mode')),
        matching: find.text('Calcular lucro'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pricing-product-cost')), '50');
    await tester.enterText(
      find.byKey(const Key('pricing-additional-costs')),
      '4',
    );
    await tester.enterText(find.byKey(const Key('pricing-fixed-fee')), '0');
    await tester.enterText(
      find.byKey(const Key('pricing-percentage-fee')),
      '15',
    );
    await tester.enterText(find.byKey(const Key('pricing-sale-price')), '90');
    await tester.ensureVisible(find.text('Calcular'));
    await tester.tap(find.text('Calcular'));
    await tester.pumpAndSettle();

    expect(find.text('Margem de lucro estimada'), findsOneWidget);
    expect(find.text('25,0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
