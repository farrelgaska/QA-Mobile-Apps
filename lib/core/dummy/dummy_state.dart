import '../../shared/models/qc_report_model.dart';
import 'dummy_reports.dart';
import '../../shared/models/user_model.dart';
import 'dummy_users.dart';
import '../../shared/models/site_model.dart';
import 'dummy_sites.dart';

class DummyState {
  static final DummyState _instance = DummyState._internal();
  factory DummyState() => _instance;
  DummyState._internal();

  UserModel currentUser = dummyUsers[0];
  SiteModel currentSite = dummySites[0];
  String? profilePictureUrl;
  
  List<QCReportModel> reports = List.from(dummyReports);

  void addReport(QCReportModel report) {
    reports.insert(0, report);
  }

  void updateReport(QCReportModel report) {
    final index = reports.indexWhere((r) => r.id == report.id);
    if (index != -1) {
      reports[index] = report;
    } else {
      reports.insert(0, report);
    }
  }
}
