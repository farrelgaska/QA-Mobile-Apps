import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../shared/models/qc_report_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3002';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3002'; // Alias to host machine from Android Emulator
      }
    } catch (_) {}
    return 'http://localhost:3002';
  }

  /// Fetch all reports from the mock API backend.
  Future<List<QCReportModel>?> fetchReports() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/reports')).timeout(
        const Duration(seconds: 4),
      );
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
  Future<List<Map<String, dynamic>>?> fetchTemplates() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/templates')).timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('[Mock API Offline - Prototype Fallback] fetchTemplates failed: $e');
    }
    return null;
  }

  /// Sync/post a report to the mock API backend.
  Future<bool> postReport(QCReportModel report) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(report.toJson()),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('[Mock API Offline - Prototype Fallback] postReport failed: $e');
      return false;
    }
  }

  /// Sync/patch a report to the mock API backend.
  Future<bool> patchReport(QCReportModel report) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/reports/${report.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(report.toJson()),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      print('[Mock API Offline - Prototype Fallback] patchReport failed: $e');
      return false;
    }
  }
}
