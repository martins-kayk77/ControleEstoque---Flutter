import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/firestore_serialization.dart';
import '../domain/app_user.dart';

class DuplicateCpfException implements Exception {
  const DuplicateCpfException();
}

class UserProfileCreationException implements Exception {
  const UserProfileCreationException(this.error);

  final Object error;
}

class MissingUserProfileException implements Exception {
  const MissingUserProfileException();
}

class UserProfileReadException implements Exception {
  const UserProfileReadException(this.error);

  final Object error;
}

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signInWithEmailAndPassword(String email, String password);
  Future<AppUser> createUserWithEmailAndPassword({
    required String displayName,
    required String cpf,
    required DateTime birthDate,
    required String email,
    required String password,
  });
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

      try {
        return await _buildAppUser(user);
      } on MissingUserProfileException {
        await _trySignOut();
        return null;
      }
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
    final user = credential.user!;

    try {
      return await _buildAppUser(user);
    } on MissingUserProfileException {
      await _trySignOut();

      rethrow;
    } on FirebaseException catch (error) {
      await _trySignOut();

      throw UserProfileReadException(error);
    } catch (error) {
      await _trySignOut();

      throw UserProfileReadException(error);
    }
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String displayName,
    required String cpf,
    required DateTime birthDate,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;

    try {
      await user.updateDisplayName(displayName);
    } on FirebaseAuthException {
      await _discardCreatedUser(user);

      rethrow;
    }

    try {
      await _assertCpfIsAvailable(cpf);
      await _writeNewUserProfile(
        user,
        displayName: displayName,
        cpf: cpf,
        birthDate: birthDate,
      );
      await _firestore.waitForPendingWrites();

      return await _buildAppUser(user);
    } on DuplicateCpfException {
      await _discardCreatedUser(user);

      rethrow;
    } on FirebaseException catch (error) {
      await _discardCreatedUser(user);

      throw UserProfileCreationException(error);
    } catch (error) {
      await _discardCreatedUser(user);

      throw UserProfileCreationException(error);
    }
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
    final userReference = _firestore.doc(FirestorePaths.user(user.uid));
    final userDocument = await userReference.get(
      const GetOptions(source: Source.server),
    );
    final data = userDocument.data();

    if (!userDocument.exists || data == null || !_hasCompleteProfile(data)) {
      throw const MissingUserProfileException();
    }

    final companyIds = _readCompanyIds(data);
    final activeCompanyId = _readActiveCompanyId(data, companyIds);

    await _tryEnsureCpfRegistry(user.uid, readString(data, 'cpf'));

    return AppUser(
      id: user.uid,
      email: user.email ?? readString(data, 'email'),
      displayName: readString(data, 'displayName'),
      cpf: readString(data, 'cpf'),
      birthDate: readDateTime(data['birthDate']),
      companyIds: companyIds,
      activeCompanyId: activeCompanyId,
    );
  }

  bool _hasCompleteProfile(Map<String, dynamic> data) {
    final displayName = readString(data, 'displayName').trim();
    final cpf = readString(data, 'cpf').replaceAll(RegExp(r'\D'), '');

    return displayName.isNotEmpty &&
        cpf.length == 11 &&
        data['birthDate'] != null;
  }

  Future<void> _tryEnsureCpfRegistry(String userId, String cpf) async {
    try {
      final cpfReference = _firestore.doc(FirestorePaths.cpfRegistry(cpf));
      final cpfDocument = await cpfReference.get();

      if (!cpfDocument.exists) {
        await cpfReference.set({
          'cpf': cpf,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException {
      return;
    }
  }

  Future<void> _assertCpfIsAvailable(String cpf) async {
    for (final cpfReference in _cpfRegistryLookupReferences(cpf)) {
      final cpfDocument = await cpfReference.get(
        const GetOptions(source: Source.server),
      );

      if (cpfDocument.exists) {
        throw const DuplicateCpfException();
      }
    }
  }

  Future<void> _writeNewUserProfile(
    User user, {
    required String displayName,
    required String cpf,
    required DateTime birthDate,
  }) async {
    final userReference = _firestore.doc(FirestorePaths.user(user.uid));
    final cpfReference = _firestore.doc(FirestorePaths.cpfRegistry(cpf));
    final cpfLookupReferences = _cpfRegistryLookupReferences(cpf);

    await _firestore.runTransaction((transaction) async {
      final cpfDocuments = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final cpfLookupReference in cpfLookupReferences) {
        cpfDocuments.add(await transaction.get(cpfLookupReference));
      }
      final userDocument = await transaction.get(userReference);

      if (cpfDocuments.any((document) => document.exists)) {
        throw const DuplicateCpfException();
      }

      if (userDocument.exists) {
        throw StateError('user-profile-already-exists');
      }

      transaction
        ..set(cpfReference, {
          'cpf': cpf,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..set(userReference, {
          'email': user.email ?? '',
          'displayName': displayName,
          'cpf': cpf,
          'birthDate': Timestamp.fromDate(
            DateTime(birthDate.year, birthDate.month, birthDate.day),
          ),
          'companyIds': <String>[],
          'activeCompanyId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    });
  }

  List<DocumentReference<Map<String, dynamic>>> _cpfRegistryLookupReferences(
    String cpf,
  ) {
    final formattedCpf = _formatCpfForLookup(cpf);
    final paths = <String>{
      FirestorePaths.cpfRegistry(cpf),
      if (formattedCpf != cpf) FirestorePaths.cpfRegistry(formattedCpf),
    };

    return paths.map(_firestore.doc).toList(growable: false);
  }

  String _formatCpfForLookup(String cpf) {
    if (cpf.length != 11) {
      return cpf;
    }

    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.'
        '${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }

  Future<void> _discardCreatedUser(User user) async {
    try {
      await user.delete();
    } on FirebaseException {
      return;
    } finally {
      await _trySignOut();
    }
  }

  Future<void> _trySignOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException {
      return;
    }
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
