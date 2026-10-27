// SDK interfaces are faked only for offline transaction tests.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// Runs the real repository against staged transactions, without a Firebase app
// or network. Reads after writes are rejected and failed callbacks commit nothing.
class MemoryFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  var nextId = 0;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      MemoryDocument(path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      MemoryCollection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = MemoryTransaction({
      for (final entry in documents.entries)
        entry.key: Map<String, dynamic>.from(entry.value),
    });
    final result = await transactionHandler(transaction);
    documents
      ..clear()
      ..addAll(transaction.documents);
    return result;
  }
}

class MemoryDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  MemoryDocument(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

class MemoryCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  MemoryCollection(this.firestore, this.path);
  @override
  final MemoryFirestore firestore;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => MemoryDocument(
    '${this.path}/${path ?? 'generated${firestore.nextId++}'}',
  );
}

class MemorySnapshot<T> extends Fake implements DocumentSnapshot<T> {
  MemorySnapshot(this.id, this.value);
  @override
  final String id;
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

class MemoryTransaction extends Fake implements Transaction {
  MemoryTransaction(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  bool wrote = false;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    if (wrote) throw StateError('Read after write');
    return MemorySnapshot<T>(ref.id, documents[ref.path] as T?);
  }

  void _write(String path, Map<String, dynamic> data, {bool update = false}) {
    wrote = true;
    if (update && !documents.containsKey(path)) {
      throw StateError('Missing document');
    }
    final target = update ? documents[path]! : <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.value == FieldValue.delete()) {
        target.remove(entry.key);
      } else {
        target[entry.key] = entry.value == FieldValue.serverTimestamp()
            ? Timestamp.fromDate(DateTime(2026, 10, 22, 12))
            : entry.value;
      }
    }
    documents[path] = target;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<String, dynamic> data,
  ) {
    _write(documentReference.path, data, update: true);
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _write(documentReference.path, Map<String, dynamic>.from(data as Map));
    return this;
  }
}
