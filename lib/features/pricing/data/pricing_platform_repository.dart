import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firebase/firestore_paths.dart';
import '../../../core/firebase/firestore_serialization.dart';
import '../domain/pricing_models.dart';

abstract class PricingPlatformRepository {
  Stream<List<PricingPlatform>> watchPlatforms(String companyId);
  Future<void> save(PricingPlatform platform);
}

final pricingPlatformRepositoryProvider = Provider<PricingPlatformRepository>((
  ref,
) {
  return FirestorePricingPlatformRepository(
    ref.watch(firebaseFirestoreProvider),
  );
});

class FirestorePricingPlatformRepository implements PricingPlatformRepository {
  const FirestorePricingPlatformRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<PricingPlatform>> watchPlatforms(String companyId) {
    return _collection(companyId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromSnapshot).toList());
  }

  @override
  Future<void> save(PricingPlatform platform) {
    return _collection(platform.companyId).doc(platform.id).set({
      'companyId': platform.companyId,
      'name': platform.name,
      'isActive': platform.isActive,
      'fees': [
        for (final fee in platform.fees)
          {
            'id': fee.id,
            'name': fee.name,
            'type': fee.type.code,
            'value': fee.value,
            'isActive': fee.isActive,
          },
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    return _firestore.collection(FirestorePaths.pricingPlatforms(companyId));
  }

  PricingPlatform _fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return PricingPlatform(
      id: snapshot.id,
      companyId: readString(data, 'companyId'),
      name: readString(data, 'name'),
      isActive: readBool(data, 'isActive', fallback: true),
      fees: _readFees(data['fees']),
    );
  }

  List<PricingFee> _readFees(Object? value) {
    if (value is! Iterable) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((fee) {
          final data = fee.map((key, value) => MapEntry(key.toString(), value));

          return PricingFee(
            id: readString(data, 'id'),
            name: readString(data, 'name'),
            type: pricingFeeTypeFromCode(readString(data, 'type')),
            value: readDouble(data, 'value'),
            isActive: readBool(data, 'isActive', fallback: true),
          );
        })
        .toList(growable: false);
  }
}
