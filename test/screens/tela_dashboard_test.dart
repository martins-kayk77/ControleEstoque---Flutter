import 'package:controle_estoque/app/theme/app_theme.dart';
import 'package:controle_estoque/features/auth/application/auth_state.dart';
import 'package:controle_estoque/features/auth/domain/app_user.dart';
import 'package:controle_estoque/features/inventory/domain/product.dart';
import 'package:controle_estoque/features/inventory/domain/stock_movement.dart';
import 'package:controle_estoque/screens/tela_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard se adapta a desktop e celular sem overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final products = [
      Product(
        id: 'product-1',
        companyId: 'company',
        name: 'Hidratante Corporal Nivea',
        acquisitionCost: 20,
        salePrice: 45,
        currentStock: 12,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
    final movements = [
      StockMovement(
        id: 'movement-1',
        companyId: 'company',
        productId: 'product-1',
        type: StockMovementType.sale,
        quantityDelta: -2,
        occurredAt: DateTime.now(),
        operationId: '1000',
      ),
    ];

    final app = ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(
              id: 'user',
              email: 'teste@gmail.com',
              companyIds: ['company'],
              activeCompanyId: 'company',
            ),
          ),
        ),
        dashboardProductsProvider(
          'company',
        ).overrideWith((ref) => Stream.value(products)),
        dashboardMovementsProvider(
          'company',
        ).overrideWith((ref) => Stream.value(movements)),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: DashboardPage()),
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Fechamento do período'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Produtos mais vendidos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
