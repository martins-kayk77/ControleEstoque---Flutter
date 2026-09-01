import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/bootstrap/firebase_bootstrap.dart';
import '../shared/widgets/page_container.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const routePath = '/settings';
  static const routeName = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebase = ref.watch(firebaseBootstrapProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Configurações',
            subtitle: 'Empresa, usuários e canais',
          ),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'Firebase',
            value: firebase.message,
          ),
          const SizedBox(height: 12),
          const _SettingsTile(
            icon: Icons.business_outlined,
            title: 'Empresa',
            value: 'Não configurada',
          ),
          const SizedBox(height: 12),
          const _SettingsTile(
            icon: Icons.group_outlined,
            title: 'Usuários',
            value: '0 vinculados',
          ),
          const SizedBox(height: 12),
          const _SettingsTile(
            icon: Icons.hub_outlined,
            title: 'Canais',
            value: '0 cadastrados',
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        enabled: false,
      ),
    );
  }
}
