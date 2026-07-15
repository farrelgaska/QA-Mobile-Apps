import '../../shared/models/qc_report_model.dart';
import '../../shared/models/qc_material_template_model.dart';
import 'dummy_reports.dart';
import '../../shared/models/user_model.dart';
import 'dummy_users.dart';
import '../../shared/models/site_model.dart';
import 'dummy_sites.dart';
import '../services/api_service.dart';

class DummyState {
  static final DummyState _instance = DummyState._internal();
  factory DummyState() => _instance;
  DummyState._internal();

  UserModel currentUser = dummyUsers[0];
  SiteModel currentSite = dummySites[0];
  String? profilePictureUrl;

  List<QCReportModel> reports = List.from(dummyReports);

  /// In-memory cache of QCMaterialTemplate objects keyed by template id.
  /// Populated when a template is first loaded (either from API or dummy list)
  /// so that re-opening a draft can reuse the exact same template.
  final Map<String, QCMaterialTemplate> templateCache = {};

  /// Fetch latest reports from Mock API backend and update memory state.
  Future<void> fetchReportsFromApi() async {
    final serverReports = await ApiService().fetchReports();
    if (serverReports != null) {
      // Create a map of server reports for O(1) lookup
      final serverMap = {for (var r in serverReports) r.id: r};

      // Update existing or add new from server
      for (final id in serverMap.keys) {
        final serverReport = serverMap[id]!;
        final idx = reports.indexWhere((r) => r.id == id);
        if (idx != -1) {
          reports[idx] = serverReport;
        } else {
          reports.add(serverReport);
        }
      }
      // Sort reports by submittedAt descending to match list order
      reports.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    }
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
  }
}
