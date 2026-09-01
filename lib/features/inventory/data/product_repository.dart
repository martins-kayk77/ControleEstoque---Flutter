import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/firestore_serialization.dart';
import '../domain/product.dart';

abstract class ProductRepository {
  Stream<List<Product>> watchProducts(String companyId);
  Future<Product?> findById(String companyId, String productId);
  Future<void> save(Product product);
  Future<void> setActive(String companyId, String productId, bool isActive);
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return FirestoreProductRepository(ref.watch(firebaseFirestoreProvider));
});

class FirestoreProductRepository implements ProductRepository {
  const FirestoreProductRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Product>> watchProducts(String companyId) {
    return _collection(companyId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromSnapshot).toList());
  }

  @override
  Future<Product?> findById(String companyId, String productId) async {
    final snapshot = await _collection(companyId).doc(productId).get();

    if (!snapshot.exists) {
      return null;
    }

    return _fromSnapshot(snapshot);
  }

  @override
  Future<void> save(Product product) {
    return _collection(
      product.companyId,
    ).doc(product.id).set(_toFirestore(product));
  }

  @override
  Future<void> setActive(String companyId, String productId, bool isActive) {
    return _collection(companyId).doc(productId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    return _firestore.collection(FirestorePaths.products(companyId));
  }

  Product _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return Product(
      id: snapshot.id,
      companyId: readString(data, 'companyId'),
      name: readString(data, 'name'),
      description: readString(data, 'description'),
      categoryId: _nullableString(data['categoryId']),
      acquisitionCost: readDouble(data, 'acquisitionCost'),
      salePrice: readDouble(data, 'salePrice'),
      currentStock: readInt(data, 'currentStock'),
      minimumStock: readInt(data, 'minimumStock'),
      reorderPoint: readInt(data, 'reorderPoint'),
      unit: readString(data, 'unit', fallback: 'un'),
      supplier: readString(data, 'supplier'),
      isActive: readBool(data, 'isActive', fallback: true),
      createdAt: readDateTime(data['createdAt']),
      updatedAt: readDateTime(data['updatedAt']),
      metadata: readObjectMap(data, 'metadata'),
    );
  }

  Map<String, Object?> _toFirestore(Product product) {
    return {
      'companyId': product.companyId,
      'name': product.name,
      'description': product.description,
      'categoryId': product.categoryId,
      'acquisitionCost': product.acquisitionCost,
      'salePrice': product.salePrice,
      'currentStock': product.currentStock,
      'minimumStock': product.minimumStock,
      'reorderPoint': product.reorderPoint,
      'unit': product.unit,
      'supplier': product.supplier,
      'isActive': product.isActive,
      'createdAt': Timestamp.fromDate(product.createdAt),
      'updatedAt': Timestamp.fromDate(product.updatedAt),
      'metadata': product.metadata,
    };
  }

  String? _nullableString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }
}
