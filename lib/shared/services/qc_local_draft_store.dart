import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QCLocalDraftStorageException implements Exception {
  const QCLocalDraftStorageException();
}

class QCLocalDraftRecord {
  final DateTime updatedAt;
  final Map<String, dynamic> payload;

  const QCLocalDraftRecord({
    required this.updatedAt,
    required this.payload,
  });
}

class QCLocalDraftStore {
  static const _version = 1;
  static const _prefix = 'qc_local_draft_v1:';

  const QCLocalDraftStore();

  Future<QCLocalDraftRecord?> read(String identity) async {
    try {
      final value = (await SharedPreferences.getInstance()).getString(
        _key(identity),
      );
      if (value == null) return null;
      final decoded = jsonDecode(value);
      if (decoded is! Map ||
          decoded['version'] != _version ||
          decoded['identity'] != identity ||
          decoded['payload'] is! Map) {
        return null;
      }
      final updatedAt =
          DateTime.tryParse(decoded['updatedAt']?.toString() ?? '');
      if (updatedAt == null) return null;
      return QCLocalDraftRecord(
        updatedAt: updatedAt,
        payload: Map<String, dynamic>.from(decoded['payload'] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String identity, Map<String, dynamic> payload) async {
    try {
      final saved = await (await SharedPreferences.getInstance()).setString(
        _key(identity),
        jsonEncode({
          'version': _version,
          'identity': identity,
          'updatedAt': DateTime.now().toIso8601String(),
          'payload': payload,
        }),
      );
      if (!saved) throw const QCLocalDraftStorageException();
    } catch (error) {
      if (error is QCLocalDraftStorageException) rethrow;
      throw const QCLocalDraftStorageException();
    }
  }

  Future<void> delete(String identity) async {
    try {
      final removed = await (await SharedPreferences.getInstance()).remove(
        _key(identity),
      );
      if (!removed) {
        final stillExists =
            (await SharedPreferences.getInstance()).containsKey(_key(identity));
        if (stillExists) throw const QCLocalDraftStorageException();
      }
    } catch (error) {
      if (error is QCLocalDraftStorageException) rethrow;
      throw const QCLocalDraftStorageException();
    }
  }

  String _key(String identity) => '$_prefix${Uri.encodeComponent(identity)}';
}
