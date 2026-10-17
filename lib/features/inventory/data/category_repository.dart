import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/firestore_serialization.dart';
import '../domain/category.dart';

abstract class CategoryRepository {
  Stream<List<Category>> watchCategories(String companyId);
  String createId(String companyId);
  Future<void> save(Category category);
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return FirestoreCategoryRepository(ref.watch(firebaseFirestoreProvider));
});

class FirestoreCategoryRepository implements CategoryRepository {
  const FirestoreCategoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  String createId(String companyId) {
    return _collection(companyId).doc().id;
  }

  @override
  Stream<List<Category>> watchCategories(String companyId) {
    return _collection(companyId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromSnapshot).toList());
  }

  @override
  Future<void> save(Category category) {
    return _collection(category.companyId).doc(category.id).set({
      'companyId': category.companyId,
      'name': category.name,
      'description': category.description,
      'isActive': category.isActive,
      'createdAt': Timestamp.fromDate(category.createdAt),
      'updatedAt': Timestamp.fromDate(category.updatedAt),
    });
  }

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    return _firestore.collection(FirestorePaths.categories(companyId));
  }

  Category _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return Category(
      id: snapshot.id,
      companyId: readString(data, 'companyId'),
      name: readString(data, 'name'),
      description: readString(data, 'description'),
      isActive: readBool(data, 'isActive', fallback: true),
      createdAt: readDateTime(data['createdAt']),
      updatedAt: readDateTime(data['updatedAt']),
    );
  }
}
