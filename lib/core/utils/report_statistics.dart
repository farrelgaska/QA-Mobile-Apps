import '../../shared/models/enums.dart';
import '../../shared/models/qc_report_model.dart';

class ReportStatistics {
  final int total;
  final int submitted;
  final int needsFollowUp;
  final int approved;

  const ReportStatistics({
    required this.total,
    required this.submitted,
    required this.needsFollowUp,
    required this.approved,
  });

  factory ReportStatistics.forStaff(
    Iterable<QCReportModel> reports,
    String staffNik,
  ) {
    final staffReports = reports
        .where((report) => report.createdByNik == staffNik)
        .toList(growable: false);
    return ReportStatistics(
      total: staffReports.length,
      submitted: staffReports
          .where((report) => report.status == QCReportStatus.SUBMITTED)
          .length,
      needsFollowUp: staffReports
          .where(
            (report) => report.status == QCReportStatus.NEEDS_FOLLOW_UP,
          )
          .length,
      approved: staffReports
          .where((report) => report.status == QCReportStatus.APPROVED)
          .length,
    );
  }
}
