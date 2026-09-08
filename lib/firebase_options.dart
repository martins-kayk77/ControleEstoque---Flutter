import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const _notConfigured = 'not-configured';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC2uc8yz7MeM0l10GZhndOB32vYx-XJ7F8',
    appId: '1:242571980105:web:69d8bbcce3312a512a3e98',
    messagingSenderId: '242571980105',
    projectId: 'myestoquecontroller',
    authDomain: 'myestoquecontroller.firebaseapp.com',
    storageBucket: 'myestoquecontroller.firebasestorage.app',
    measurementId: 'G-PN0NHDS7SW',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBkIJ7Tu8R08eX4hVvJ5k8kPwPBhY4ckqE',
    appId: '1:242571980105:android:24c3b2ffa48ab2f92a3e98',
    messagingSenderId: '242571980105',
    projectId: 'myestoquecontroller',
    storageBucket: 'myestoquecontroller.firebasestorage.app',
  );
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => throw UnsupportedError(
        'Firebase configurado inicialmente apenas para Android e Web.',
      ),
    };
  }

  static bool get isConfiguredForCurrentPlatform {
    try {
      return _hasRequiredValues(currentPlatform);
    } on UnsupportedError {
      return false;
    }
  }

  static bool _hasRequiredValues(FirebaseOptions options) {
    final requiredValues = [
      options.apiKey,
      options.appId,
      options.messagingSenderId,
      options.projectId,
    ];

    return requiredValues.every(
      (value) => value.trim().isNotEmpty && value != _notConfigured,
    );
  }
}
