import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseBootstrap = await FirebaseBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: [
        firebaseBootstrapProvider.overrideWithValue(firebaseBootstrap),
      ],
      child: const InventoryApp(),
    ),
  );
}
