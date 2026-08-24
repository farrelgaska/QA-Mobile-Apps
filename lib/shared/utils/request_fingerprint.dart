import 'dart:convert';

/// Generates a stable canonical semantic fingerprint for a JSON-serializable payload.
/// It sorts map keys recursively and ignores specified transient fields to ensure
/// deterministic equivalence for idempotency checks during a session.
String generateSemanticFingerprint(
  Map<String, dynamic> payload, {
  Set<String> excludeKeys = const {'template_snapshot', 'migration_metadata', 'created_at', 'updated_at', 'date', 'submitted_at'},
}) {
  final canonicalObj = _canonicalize(payload, excludeKeys);
  return jsonEncode(canonicalObj);
}

dynamic _canonicalize(dynamic value, Set<String> excludeKeys) {
  if (value is Map) {
    final sortedKeys = value.keys.cast<String>().where((k) => !excludeKeys.contains(k)).toList()..sort();
    final canonicalMap = <String, dynamic>{};
    for (final key in sortedKeys) {
      final val = value[key];
      if (val != null) {
        canonicalMap[key] = _canonicalize(val, excludeKeys);
      }
    }
    return canonicalMap;
  } else if (value is List) {
    return value.map((v) => _canonicalize(v, excludeKeys)).toList();
  } else {
    // Primitives
    return value;
  }
}
