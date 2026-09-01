import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap/firebase_bootstrap.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  _assertFirebaseReady(ref);
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  _assertFirebaseReady(ref);
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  _assertFirebaseReady(ref);
  return FirebaseStorage.instance;
});

void _assertFirebaseReady(Ref ref) {
  final bootstrap = ref.watch(firebaseBootstrapProvider);

  if (!bootstrap.isReady) {
    throw StateError('Firebase ainda não foi configurado para este ambiente.');
  }
}
