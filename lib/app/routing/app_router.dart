import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_state.dart';
import '../../screens/tela_acesso.dart';
import '../../screens/tela_configuracoes.dart';
import '../../screens/tela_painel.dart';
import '../../screens/tela_precos.dart';
import '../../screens/telas_estoque.dart';
import '../../shared/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final authFlow = ref.watch(authFlowProvider);
  final router = GoRouter(
    initialLocation: DashboardPage.routePath,
    redirect: (context, state) {
      final isLoginRoute = state.uri.path == LoginPage.routePath;
      final isAuthenticated = authState.asData?.value != null;

      if (authFlow != AuthFlow.idle) {
        return isLoginRoute ? null : LoginPage.routePath;
      }

      if (!isAuthenticated && !isLoginRoute) {
        final from = Uri.encodeComponent(state.uri.toString());
        return '${LoginPage.routePath}?from=$from';
      }

      if (isAuthenticated && isLoginRoute) {
        final from = state.uri.queryParameters['from'];
        return from == null || from.isEmpty
            ? DashboardPage.routePath
            : Uri.decodeComponent(from);
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentPath: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: DashboardPage.routePath,
            name: DashboardPage.routeName,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: ProductsPage.routePath,
            name: ProductsPage.routeName,
            builder: (context, state) => const ProductsPage(),
          ),
          GoRoute(
            path: StockMovementsPage.routePath,
            name: StockMovementsPage.routeName,
            builder: (context, state) => const StockMovementsPage(),
          ),
          GoRoute(
            path: StockCountsPage.routePath,
            name: StockCountsPage.routeName,
            builder: (context, state) => const StockCountsPage(),
          ),
          GoRoute(
            path: PricingPage.routePath,
            name: PricingPage.routeName,
            builder: (context, state) => const PricingPage(),
          ),
          GoRoute(
            path: SettingsPage.routePath,
            name: SettingsPage.routeName,
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: LoginPage.routePath,
        name: LoginPage.routeName,
        builder: (context, state) => const LoginPage(),
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Página não encontrada'))),
  );

  ref.onDispose(router.dispose);

  return router;
});
