import 'package:cloud_firestore/cloud_firestore.dart';

DateTime readDateTime(Object? value, {DateTime? fallback}) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value) ??
        fallback ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

String readString(
  Map<String, dynamic> data,
  String key, {
  String fallback = '',
}) {
  final value = data[key];
  return value is String ? value : fallback;
}

int readInt(Map<String, dynamic> data, String key, {int fallback = 0}) {
  final value = data[key];
  return value is num ? value.toInt() : fallback;
}

double readDouble(
  Map<String, dynamic> data,
  String key, {
  double fallback = 0,
}) {
  final value = data[key];
  return value is num ? value.toDouble() : fallback;
}

bool readBool(Map<String, dynamic> data, String key, {bool fallback = false}) {
  final value = data[key];
  return value is bool ? value : fallback;
}

Map<String, Object?> readObjectMap(Map<String, dynamic> data, String key) {
  final value = data[key];

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  return const {};
}
