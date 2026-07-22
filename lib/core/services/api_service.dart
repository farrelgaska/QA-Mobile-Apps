import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show kIsWeb, kReleaseMode, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/models/qc_report_model.dart';

class QCEvidenceUploadResult {
  final String objectPath;
  final String mimeType;
  final int size;

  const QCEvidenceUploadResult({
    required this.objectPath,
    required this.mimeType,
    required this.size,
  });
}

class ApiRequestException implements Exception {
  final String message;

  const ApiRequestException(this.message);

  @override
  String toString() => message;
}

@visibleForTesting
String resolveApiBaseUrl({
  required String configuredBaseUrl,
  required bool isWeb,
  required bool isReleaseMode,
  required bool isAndroid,
}) {
  final normalized = configuredBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  if (normalized.isNotEmpty) {
    final uri = Uri.tryParse(normalized);
    final isAbsoluteHttpUrl =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
    final isValidProductionWebUrl =
        !isWeb || !isReleaseMode || uri?.scheme == 'https';
    if (!isAbsoluteHttpUrl || !isValidProductionWebUrl) {
      throw StateError(
        'API_BASE_URL harus berupa URL HTTP(S) absolut tanpa query atau fragment. '
        'Build Flutter Web production wajib menggunakan URL HTTPS.',
      );
    }
    return normalized;
  }

  if (isWeb) {
    if (isReleaseMode) {
      throw StateError(
        'API_BASE_URL wajib diatur untuk build Flutter Web production. '
        'Gunakan --dart-define=API_BASE_URL=https://backend.example.com.',
      );
    }
    return 'http://localhost:3002';
  }
  if (isAndroid) {
    return 'http://10.0.2.2:3002';
  }
  return 'http://localhost:3002';
}

class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() : _client = null;

  @visibleForTesting
  ApiService.withClient(http.Client client) : _client = client;

  final http.Client? _client;

  static bool get _isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {}
    return false;
  }

  String get baseUrl => resolveApiBaseUrl(
    configuredBaseUrl: _configuredBaseUrl,
    isWeb: kIsWeb,
    isReleaseMode: kReleaseMode,
    isAndroid: _isAndroid,
  );

  static void validateConfiguration() => ApiService().baseUrl;

  /// Fetch all reports from the mock API backend.
  Future<List<QCReportModel>?> fetchReports() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/reports'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((json) => QCReportModel.fromJson(json)).toList();
      }
    } catch (e) {
      print('[Mock API Offline - Prototype Fallback] fetchReports failed: $e');
    }
    return null;
  }

  /// Fetch all QC templates from the mock API backend.
  /// Returns a list of raw JSON maps, or null if the API is unavailable.
  Future<List<Map<String, dynamic>>> fetchTemplates([String? type]) async {
    try {
      final url = type != null
          ? '$baseUrl/templates?type=$type'
          : '$baseUrl/templates';
      var response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 304) {
        final retryUri = Uri.parse(url).replace(
          queryParameters: {
            ...Uri.parse(url).queryParameters,
            '_cache_bust': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
        response = await http.get(retryUri).timeout(const Duration(seconds: 4));
      }
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print(
        '[Mock API Offline - Prototype Fallback] fetchTemplates failed: $e',
      );
    }
    throw ApiRequestException(
      'Template tidak dapat dimuat. Periksa koneksi lalu coba lagi.',
    );
  }

  /// Sync/post a report to the mock API backend.
  Future<bool> postReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/reports');
      final response =
          await (_client?.post(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(report.toJson()),
                  ) ??
                  http.post(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(report.toJson()),
                  ))
              .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      if (response.statusCode == 409) {
        throw ApiRequestException(
          'Laporan dengan ID ${report.id} sudah tersimpan. Muat ulang daftar laporan sebelum mencoba lagi.',
        );
      }
      throw ApiRequestException(
        'Laporan gagal disimpan (HTTP ${response.statusCode}). Silakan coba lagi.',
      );
    } on ApiRequestException catch (error) {
      if (throwOnError) rethrow;
      print(
        '[Mock API Offline - Prototype Fallback] postReport failed: $error',
      );
      return false;
    } catch (error) {
      if (await _reportExists(report.id)) return true;
      final exception = ApiRequestException(
        'Tidak dapat terhubung ke server saat menyimpan laporan: $error',
      );
      if (throwOnError) throw exception;
      print(
        '[Mock API Offline - Prototype Fallback] postReport failed: $error',
      );
      return false;
    }
  }

  /// Sync/patch a report to the mock API backend.
  Future<bool> patchReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/reports/${report.id}');
      final response =
          await (_client?.patch(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(report.toJson()),
                  ) ??
                  http.patch(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(report.toJson()),
                  ))
              .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return true;
      if (response.statusCode == 409) {
        throw ApiRequestException(
          'Perubahan laporan ${report.id} konflik dengan data yang sudah tersimpan. Muat ulang laporan sebelum mencoba lagi.',
        );
      }
      throw ApiRequestException(
        'Laporan gagal diperbarui (HTTP ${response.statusCode}). Silakan coba lagi.',
      );
    } on ApiRequestException catch (error) {
      if (throwOnError) rethrow;
      print(
        '[Mock API Offline - Prototype Fallback] patchReport failed: $error',
      );
      return false;
    } catch (error) {
      final exception = ApiRequestException(
        'Tidak dapat terhubung ke server saat memperbarui laporan: $error',
      );
      if (throwOnError) throw exception;
      print(
        '[Mock API Offline - Prototype Fallback] patchReport failed: $error',
      );
      return false;
    }
  }

  Future<bool> _reportExists(String reportId) async {
    try {
      final uri = Uri.parse('$baseUrl/reports/$reportId');
      final response = await (_client?.get(uri) ?? http.get(uri)).timeout(
        const Duration(seconds: 4),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<QCEvidenceUploadResult> uploadQCEvidence({
    required XFile file,
    required String reportId,
    required String itemId,
  }) async {
    final mimeType = _supportedImageMimeType(file);
    if (mimeType == null) {
      throw const ApiRequestException(
        'Format foto tidak didukung. Gunakan JPEG, PNG, WebP, atau HEIC.',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('$baseUrl/uploads/qc-evidence'),
            )
            ..fields['report_id'] = reportId
            ..fields['category'] = 'checklist'
            ..fields['item_id'] = itemId
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: file.name,
                contentType: MediaType.parse(mimeType),
              ),
            );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final body = _decodeObject(response.body);
      if (response.statusCode != 201) {
        throw ApiRequestException(
          body?['error']?.toString() ?? 'Foto gagal diunggah.',
        );
      }

      final objectPath = body?['object_path'];
      final responseMimeType = body?['mime_type'];
      final size = body?['size'];
      if (objectPath is! String ||
          objectPath.isEmpty ||
          responseMimeType is! String ||
          size is! num) {
        throw const ApiRequestException(
          'Respons upload foto dari server tidak valid.',
        );
      }

      return QCEvidenceUploadResult(
        objectPath: objectPath,
        mimeType: responseMimeType,
        size: size.toInt(),
      );
    } on ApiRequestException {
      rethrow;
    } catch (_) {
      throw const ApiRequestException(
        'Foto gagal diunggah. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  Future<Map<String, String>> resolveQCEvidenceSignedUrls(
    List<String> objectPaths,
  ) async {
    if (objectPaths.isEmpty) return const {};

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/uploads/qc-evidence/signed-urls'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'paths': objectPaths}),
          )
          .timeout(const Duration(seconds: 10));
      final body = _decodeObject(response.body);
      if (response.statusCode != 200) {
        throw ApiRequestException(
          body?['error']?.toString() ?? 'URL foto tidak dapat dimuat.',
        );
      }

      final entries = body?['signed_urls'];
      if (entries is! List) {
        throw const ApiRequestException(
          'Respons URL foto dari server tidak valid.',
        );
      }

      final resolved = <String, String>{};
      for (final entry in entries) {
        if (entry is! Map) continue;
        final objectPath = entry['object_path'];
        final signedUrl = entry['signed_url'];
        if (objectPath is String && signedUrl is String) {
          resolved[objectPath] = signedUrl;
        }
      }
      return resolved;
    } on ApiRequestException {
      rethrow;
    } catch (_) {
      throw const ApiRequestException(
        'URL foto tidak dapat dimuat. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  Map<String, dynamic>? _decodeObject(String body) {
    if (body.isEmpty) return null;
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  String? _supportedImageMimeType(XFile file) {
    final claimedMime = file.mimeType?.toLowerCase();
    const supported = {'image/jpeg', 'image/png', 'image/webp', 'image/heic'};
    if (claimedMime != null && supported.contains(claimedMime)) {
      return claimedMime;
    }

    final name = file.name.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    return null;
  }
}
