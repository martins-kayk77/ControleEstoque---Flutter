import 'package:controle_estoque/app/theme/app_theme.dart';
import 'package:controle_estoque/features/auth/application/auth_state.dart';
import 'package:controle_estoque/features/auth/domain/app_user.dart';
import 'package:controle_estoque/features/inventory/domain/stock_count.dart';
import 'package:controle_estoque/features/inventory/presentation/stock_count_report.dart';
import 'package:controle_estoque/screens/tela_comparacao_contagens.dart';
import 'package:controle_estoque/screens/tela_contagens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

StockCount report(String id, int number, int day, int expected, int found) =>
    StockCount(
      id: id,
      number: number,
      companyId: 'c',
      startedAt: DateTime(2026, 10, day),
      completedAt: DateTime(2026, 10, day, 12),
      status: StockCountStatus.completed,
      responsibleName: 'Responsável',
      items: [
        StockCountItem(
          id: 'a',
          productId: 'a',
          productName: 'Produto A',
          expectedQuantity: expected,
          countedQuantity: found,
        ),
      ],
    );

Future<GoRouter> mount(
  WidgetTester tester, {
  required String location,
  required Stream<List<StockCount>> Function() counts,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/counts',
        builder: (_, _) => const Scaffold(body: StockCountsPage()),
      ),
      GoRoute(
        path: StockCountComparisonPage.routePath,
        builder: (_, state) => Scaffold(
          body: StockCountComparisonPage(
            countId: state.pathParameters['countId']!,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
        stockCountsProvider('c').overrideWith((ref) => counts()),
        countProductsProvider(
          'c',
        ).overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'abre relatório, navega para comparação e volta ao histórico em $width pixels',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final before = report('older', 1, 1, 20, 20);
        final after = report('newer', 2, 8, 17, 15);
        final router = await mount(
          tester,
          location: '/counts',
          counts: () => Stream.value([after, before]),
        );
        expect(find.text('Comparar relatórios'), findsNothing);
        await tester.ensureVisible(find.text('Ver relatório').last);
        await tester.tap(find.text('Ver relatório').last);
        await tester.pumpAndSettle();
        expect(find.text('Relatório de contagem CT-0001'), findsOneWidget);
        await tester.tap(find.text('Comparar'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/counts/older/compare');
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('Relatório aberto'), findsOneWidget);
        expect(find.text(countTitle(before)), findsOneWidget);
        expect(find.text('Variação física: -5 • Registrada: -3'), findsNothing);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(countTitle(after)).last);
        await tester.pumpAndSettle();
        expect(
          find.text('Variação física: -5 • Registrada: -3'),
          findsOneWidget,
        );
        expect(
          find.text('${countTitle(before)} → ${countTitle(after)}'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Voltar'));
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/counts');
        expect(find.text('Histórico de relatórios'), findsOneWidget);
        expect(find.text('Comparar relatórios'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'acesso direto mantém relatório de origem e permite escolher outro anterior',
    (tester) async {
      final before = report('older', 1, 1, 20, 20);
      final after = report('newer', 2, 8, 17, 15);
      final router = await mount(
        tester,
        location: '/counts/newer/compare',
        counts: () => Stream.value([after, before]),
      );
      expect(find.text(countTitle(after)), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(countTitle(before)).last);
      await tester.pumpAndSettle();
      expect(find.text('Variação física: -5 • Registrada: -3'), findsOneWidget);
      await tester.ensureVisible(find.text('Voltar'));
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/counts');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'um único relatório mostra orientação, sem comparar consigo mesmo',
    (tester) async {
      await mount(
        tester,
        location: '/counts/only/compare',
        counts: () => Stream.value([report('only', 1, 1, 20, 20)]),
      );
      expect(
        find.text('Conclua outra contagem para comparar dois relatórios.'),
        findsOneWidget,
      );
      expect(find.text('Escolha outro relatório'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'relatório ausente informa usuário e não escolhe outro silenciosamente',
    (tester) async {
      await mount(
        tester,
        location: '/counts/missing/compare',
        counts: () => Stream.value([report('other', 1, 1, 20, 20)]),
      );
      expect(
        find.text(
          'Relatório não encontrado nesta empresa. Volte ao histórico e abra outro relatório.',
        ),
        findsOneWidget,
      );
      expect(find.text('Relatório aberto'), findsNothing);
    },
  );

  testWidgets('falha de carregamento permite tentar novamente', (tester) async {
    var fail = true;
    await mount(
      tester,
      location: '/counts/only/compare',
      counts: () => fail
          ? Stream.error(StateError('offline'))
          : Stream.value([report('only', 1, 1, 20, 20)]),
    );
    expect(
      find.text('Não foi possível carregar os relatórios.'),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Relatório aberto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
