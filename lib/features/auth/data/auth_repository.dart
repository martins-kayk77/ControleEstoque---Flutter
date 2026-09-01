import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/firestore_serialization.dart';
import '../domain/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signInWithEmailAndPassword(String email, String password);
  Future<AppUser> createUserWithEmailAndPassword(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        return null;
      }

      return _buildAppUser(user);
    });
  }

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      companyIds: const [],
    );
  }

  @override
  Future<AppUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return _buildAppUser(credential.user!);
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    return _buildAppUser(credential.user!);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<AppUser> _buildAppUser(User user) async {
    final userDocument = await _firestore
        .doc(FirestorePaths.user(user.uid))
        .get();
    final data = userDocument.data();
    final companyIds = _readCompanyIds(data);
    final activeCompanyId = _readActiveCompanyId(data, companyIds);

    return AppUser(
      id: user.uid,
      email:
          user.email ?? readString(data ?? const <String, dynamic>{}, 'email'),
      displayName: readString(
        data ?? const <String, dynamic>{},
        'displayName',
        fallback: user.displayName ?? '',
      ),
      companyIds: companyIds,
      activeCompanyId: activeCompanyId,
    );
  }

  List<String> _readCompanyIds(Map<String, dynamic>? data) {
    final value = data?['companyIds'];

    if (value is Iterable) {
      return value.whereType<String>().toList(growable: false);
    }

    return const [];
  }

  String? _readActiveCompanyId(
    Map<String, dynamic>? data,
    List<String> companyIds,
  ) {
    final activeCompanyId = data?['activeCompanyId'];

    if (activeCompanyId is String && activeCompanyId.isNotEmpty) {
      return activeCompanyId;
    }

    return companyIds.isEmpty ? null : companyIds.first;
  }
}
