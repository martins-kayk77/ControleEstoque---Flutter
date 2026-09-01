import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

enum FirebaseBootstrapStatus { initialized, notConfigured, failed }

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({
    required this.status,
    required this.message,
    this.error,
  });

  const FirebaseBootstrapResult.initialized()
    : this(
        status: FirebaseBootstrapStatus.initialized,
        message: 'Firebase ativo',
      );

  const FirebaseBootstrapResult.notConfigured()
    : this(
        status: FirebaseBootstrapStatus.notConfigured,
        message: 'Firebase pendente',
      );

  const FirebaseBootstrapResult.failed(Object error)
    : this(
        status: FirebaseBootstrapStatus.failed,
        message: 'Firebase indisponível',
        error: error,
      );

  final FirebaseBootstrapStatus status;
  final String message;
  final Object? error;

  bool get isReady => status == FirebaseBootstrapStatus.initialized;
}

final firebaseBootstrapProvider = Provider<FirebaseBootstrapResult>(
  (ref) => const FirebaseBootstrapResult.notConfigured(),
);

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<FirebaseBootstrapResult> initialize() async {
    if (!DefaultFirebaseOptions.isConfiguredForCurrentPlatform) {
      return const FirebaseBootstrapResult.notConfigured();
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      return const FirebaseBootstrapResult.initialized();
    } catch (error) {
      return FirebaseBootstrapResult.failed(error);
    }
  }
}
