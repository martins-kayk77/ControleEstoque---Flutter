import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/dashboard_page.dart';
import '../../screens/inventory_placeholder_page.dart';
import '../../screens/login_page.dart';
import '../../screens/pricing_page.dart';
import '../../screens/settings_page.dart';
import '../../shared/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: DashboardPage.routePath,
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
});
