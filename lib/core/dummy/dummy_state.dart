import 'package:flutter/foundation.dart';
import '../../shared/models/qc_report_model.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/qc_material_template_model.dart';
import '../../shared/models/pekerjaan_model.dart';
import '../../shared/models/user_model.dart';
import 'dummy_users.dart';
import '../../shared/models/site_model.dart';
import 'dummy_sites.dart';
import '../services/api_service.dart';

class DummyState extends ChangeNotifier {
  static final DummyState _instance = DummyState._internal();
  factory DummyState() => _instance;
  DummyState._internal();

  UserModel currentUser = dummyUsers[0];
  SiteModel currentSite = dummySites[0];
  List<QCReportModel> reports = [];
  String? reportsLoadError;
  Future<void>? _reportsFetchInFlight;

  /// In-memory cache of QCMaterialTemplate objects keyed by template id.
  /// Populated when a template is first loaded (either from API or dummy list)
  /// so that re-opening a draft can reuse the exact same template.
  final Map<String, QCMaterialTemplate> templateCache = {};
  final Map<String, PekerjaanModel> workTemplateCache = {};

  /// Fetch latest reports from Mock API backend and update memory state.
  Future<void> fetchReportsFromApi({
    ApiService? apiService,
    Duration retryDelay = const Duration(milliseconds: 750),
  }) {
    final inFlight = _reportsFetchInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> request;
    request = _fetchReportsWithRetry(apiService ?? ApiService(), retryDelay)
        .whenComplete(() {
      if (identical(_reportsFetchInFlight, request)) {
        _reportsFetchInFlight = null;
      }
    });
    _reportsFetchInFlight = request;
    return request;
  }

  Future<void> _fetchReportsWithRetry(
    ApiService apiService,
    Duration retryDelay,
  ) async {
    if (reportsLoadError != null) {
      reportsLoadError = null;
      notifyListeners();
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final serverReports = await apiService.fetchReports();
        debugPrint(
          '[DummyState] Fetched ${serverReports.length} reports from API',
        );
        reports = List<QCReportModel>.from(serverReports)
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        reportsLoadError = null;
        notifyListeners();
        return;
      } catch (error) {
        final canRetry = attempt == 0 && _isTransientReportError(error);
        if (canRetry) {
          debugPrint(
              '[DummyState] Transient report fetch error; retrying: $error');
          await Future<void>.delayed(retryDelay);
          continue;
        }

        debugPrint('[DummyState] Error fetching reports: $error');
        reports = [];
        reportsLoadError =
            'Laporan tidak dapat dimuat. Periksa koneksi lalu coba lagi.';
        notifyListeners();
        rethrow;
      }
    }
  }

  bool _isTransientReportError(Object error) {
    if (error is! ApiRequestException) return false;
    return error.code == 'NETWORK_ERROR' ||
        error.statusCode == 502 ||
        error.statusCode == 503 ||
        error.statusCode == 504;
  }

  /// Refresh one report from the authoritative detail endpoint and replace any
  /// stale list snapshot with the same ID.
  Future<QCReportModel> fetchReportFromApi(
    String reportId, {
    ApiService? apiService,
  }) async {
    final serverReport = await (apiService ?? ApiService()).fetchReport(
      reportId,
      throwOnError: true,
    );
    if (serverReport == null) {
      throw ApiRequestException('Laporan $reportId tidak ditemukan.');
    }
    updateReportLocally(serverReport);
    return serverReport;
  }

  void mergeReportsFromApi(List<QCReportModel> serverReports) {
    final serverMap = {for (var report in serverReports) report.id: report};
    for (final id in serverMap.keys) {
      final serverReport = serverMap[id]!;
      final index = reports.indexWhere((report) => report.id == id);
      if (index == -1) {
        reports.add(serverReport);
        continue;
      }

      final localReport = reports[index];
      final keepNewerLocalDraft = localReport.status == QCReportStatus.DRAFT &&
          localReport.submittedAt.isAfter(serverReport.submittedAt);
      if (!keepNewerLocalDraft) reports[index] = serverReport;
    }
    reports.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    notifyListeners();
  }

  void addReport(QCReportModel report) {
    addReportLocally(report);
    // Async push to backend server
    ApiService().postReport(report);
  }

  void addReportLocally(QCReportModel report) {
    final idx = reports.indexWhere((r) => r.id == report.id);
    if (idx != -1) {
      reports[idx] = report;
    } else {
      reports.insert(0, report);
    }
    notifyListeners();
  }

  void updateReport(QCReportModel report) {
    updateReportLocally(report);
    // Async push to backend server
    ApiService().patchReport(report);
  }

  void updateReportLocally(QCReportModel report) {
    final index = reports.indexWhere((r) => r.id == report.id);
    if (index != -1) {
      reports[index] = report;
    } else {
      reports.insert(0, report);
    }
    notifyListeners();
  }
}
