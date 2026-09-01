import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/firestore_serialization.dart';
import '../domain/company.dart';

abstract class CompanyRepository {
  Stream<Company?> watchCompany(String companyId);
  Future<void> save(Company company);
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return FirestoreCompanyRepository(ref.watch(firebaseFirestoreProvider));
});

class FirestoreCompanyRepository implements CompanyRepository {
  const FirestoreCompanyRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<Company?> watchCompany(String companyId) {
    return _document(companyId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return _fromSnapshot(snapshot);
    });
  }

  @override
  Future<void> save(Company company) {
    return _document(company.id).set({
      'name': company.name,
      'tradeName': company.tradeName,
      'documentNumber': company.documentNumber,
      'createdBy': company.createdBy,
      'isActive': company.isActive,
      'createdAt': Timestamp.fromDate(company.createdAt),
      'updatedAt': Timestamp.fromDate(company.updatedAt),
      'settings': company.settings,
    });
  }

  DocumentReference<Map<String, dynamic>> _document(String companyId) {
    return _firestore.doc(FirestorePaths.company(companyId));
  }

  Company _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return Company(
      id: snapshot.id,
      name: readString(data, 'name'),
      tradeName: readString(data, 'tradeName'),
      documentNumber: readString(data, 'documentNumber'),
      createdBy: readString(data, 'createdBy'),
      isActive: readBool(data, 'isActive', fallback: true),
      createdAt: readDateTime(data['createdAt']),
      updatedAt: readDateTime(data['updatedAt']),
      settings: readObjectMap(data, 'settings'),
    );
  }
}
