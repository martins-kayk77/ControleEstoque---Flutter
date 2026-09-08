import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/data/auth_repository.dart';
import 'brand_logo.dart';

class AppShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _selectedIndexFor(currentPath);
    final user = ref.watch(authStateProvider).asData?.value;
    final userLabel = user?.email.isNotEmpty == true
        ? user!.email
        : user?.displayName ?? 'Conta ativa';

    Future<void> signOut() async {
      try {
        await ref.read(authRepositoryProvider).signOut();

        if (context.mounted) {
          context.go('/login');
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Não foi possível sair da conta.')),
            );
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.medium) {
          return _DesktopShell(
            selectedIndex: selectedIndex,
            userLabel: userLabel,
            onSignOut: signOut,
            child: child,
          );
        }

        return _MobileShell(
          selectedIndex: selectedIndex,
          userLabel: userLabel,
          onSignOut: signOut,
          child: child,
        );
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
  const _DesktopShell({
    required this.selectedIndex,
    required this.userLabel,
    required this.onSignOut,
    required this.child,
  });

  final int selectedIndex;
  final String userLabel;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isExpanded =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

    return Scaffold(
      body: Row(
        children: [
          _SideBar(
            selectedIndex: selectedIndex,
            isExpanded: isExpanded,
            userLabel: userLabel,
            onSignOut: onSignOut,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.selectedIndex,
    required this.isExpanded,
    required this.userLabel,
    required this.onSignOut,
  });

  final int selectedIndex;
  final bool isExpanded;
  final String userLabel;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = isExpanded ? 260.0 : 88.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            child: Column(
              crossAxisAlignment: isExpanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isExpanded ? 6 : 0),
                  child: BrandLogo(size: 46, showName: isExpanded),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: ListView.separated(
                    itemCount: AppShell.destinations.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final destination = AppShell.destinations[index];

                      return _SideBarItem(
                        destination: destination,
                        isSelected: selectedIndex == index,
                        isExpanded: isExpanded,
                        onTap: () => context.go(destination.route),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _AccountBadge(isExpanded: isExpanded, userLabel: userLabel),
                const SizedBox(height: 8),
                _SignOutButton(isExpanded: isExpanded, onSignOut: onSignOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideBarItem extends StatelessWidget {
  const _SideBarItem({
    required this.destination,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final AppDestination destination;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isSelected ? colorScheme.primary : colorScheme.onSurface;
    final background = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.78)
        : Colors.transparent;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: isExpanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? destination.selectedIcon : destination.icon,
            color: foreground,
            size: 22,
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: destination.label,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.isExpanded, required this.userLabel});

  final bool isExpanded;
  final String userLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!isExpanded) {
      return Tooltip(
        message: userLabel,
        child: Icon(Icons.account_circle_outlined, color: AppTheme.aqua),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.account_circle_outlined, color: AppTheme.aqua, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conta ativa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  userLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.isExpanded, required this.onSignOut});

  final bool isExpanded;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = SizedBox(
      height: 46,
      child: Row(
        mainAxisAlignment: isExpanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(Icons.logout, color: colorScheme.onSurfaceVariant, size: 21),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Text(
              'Sair',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: 'Sair',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () => onSignOut(),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 0),
          child: content,
        ),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.userLabel,
    required this.onSignOut,
    required this.child,
  });

  final int selectedIndex;
  final String userLabel;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandLogo(size: 34, showName: true)),
      drawer: NavigationDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          context.go(AppShell.destinations[index].route);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLogo(size: 50, showName: true),
                const SizedBox(height: 8),
                Text(
                  userLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final destination in AppShell.destinations)
            NavigationDrawerDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: Text(destination.label),
            ),
          const Divider(height: 20),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () async {
              Navigator.of(context).pop();
              await onSignOut();
            },
          ),
        ],
      ),
      body: child,
    );
  }
}
