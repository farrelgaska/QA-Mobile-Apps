import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/report_statistics.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_report_model.dart';

QCReportModel _report(int index, QCReportStatus status, {String? nik}) =>
    QCReportModel(
      id: 'report-$index',
      title: 'Laporan $index',
      type: QCType.material,
      status: status,
      staffNote: '',
      createdByNik: nik ?? 'NIK-908271',
    );

void main() {
  test('statistik Home menghitung 15/9/3/3 dari respons backend', () {
    final reports = <QCReportModel>[
      for (var index = 0; index < 9; index++)
        _report(index, QCReportStatus.SUBMITTED),
      for (var index = 9; index < 12; index++)
        _report(index, QCReportStatus.NEEDS_FOLLOW_UP),
      for (var index = 12; index < 15; index++)
        _report(index, QCReportStatus.APPROVED),
      _report(99, QCReportStatus.APPROVED, nik: 'STAFF-LAIN'),
    ];

    final result = ReportStatistics.forStaff(reports, 'NIK-908271');

    expect(result.total, 15);
    expect(result.submitted, 9);
    expect(result.needsFollowUp, 3);
    expect(result.approved, 3);
  });
}
