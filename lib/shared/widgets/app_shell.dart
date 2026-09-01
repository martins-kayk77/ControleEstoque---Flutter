import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_breakpoints.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  static const destinations = [
    AppDestination(
      label: 'Dashboard',
      route: '/',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    AppDestination(
      label: 'Produtos',
      route: '/products',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    AppDestination(
      label: 'Estoque',
      route: '/stock',
      icon: Icons.sync_alt_outlined,
      selectedIcon: Icons.sync_alt,
    ),
    AppDestination(
      label: 'Contagens',
      route: '/counts',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
    ),
    AppDestination(
      label: 'Preços',
      route: '/pricing',
      icon: Icons.calculate_outlined,
      selectedIcon: Icons.calculate,
    ),
    AppDestination(
      label: 'Configurações',
      route: '/settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndexFor(currentPath);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.medium) {
          return _DesktopShell(selectedIndex: selectedIndex, child: child);
        }

        return _MobileShell(selectedIndex: selectedIndex, child: child);
      },
    );
  }

  static int _selectedIndexFor(String path) {
    if (path == '/') {
      return 0;
    }

    final index = destinations.indexWhere(
      (destination) =>
          destination.route != '/' && path.startsWith(destination.route),
    );

    return index == -1 ? 0 : index;
  }
}

class AppDestination {
  const AppDestination({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.selectedIndex, required this.child});

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended:
                  MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                context.go(AppShell.destinations[index].route);
              },
              labelType: NavigationRailLabelType.none,
              minExtendedWidth: 220,
              leading: const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: _BrandMark(),
              ),
              destinations: [
                for (final destination in AppShell.destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.selectedIndex, required this.child});

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentDestination = AppShell.destinations[selectedIndex];

    return Scaffold(
      appBar: AppBar(title: Text(currentDestination.label)),
      drawer: NavigationDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          context.go(AppShell.destinations[index].route);
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 20, 28, 12),
            child: _BrandMark(),
          ),
          for (final destination in AppShell.destinations)
            NavigationDrawerDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: Text(destination.label),
            ),
        ],
      ),
      body: child,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Controle de Estoque',
      child: CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: const Icon(Icons.storefront),
      ),
    );
  }
}
