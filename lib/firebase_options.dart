import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const _notConfigured = 'not-configured';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: _notConfigured,
    ),
    appId: String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: _notConfigured,
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _notConfigured,
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _notConfigured,
    ),
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: _notConfigured,
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _notConfigured,
    ),
    measurementId: String.fromEnvironment(
      'FIREBASE_MEASUREMENT_ID',
      defaultValue: _notConfigured,
    ),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: _notConfigured,
    ),
    appId: String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: _notConfigured,
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: _notConfigured,
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: _notConfigured,
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: _notConfigured,
    ),
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
