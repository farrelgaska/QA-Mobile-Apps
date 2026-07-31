import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/dashboard/screens/dashboard_screen.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_report_model.dart';

QCReportModel _report(
  String id,
  DateTime submittedAt, {
  QCReportStatus status = QCReportStatus.SUBMITTED,
}) {
  return QCReportModel(
    id: id,
    title: 'Laporan $id',
    type: QCType.material,
    status: status,
    staffNote: '',
    submittedAt: submittedAt,
  );
}

void main() {
  final now = DateTime(2026, 7, 31, 12);
  final reports = [
    _report('today', DateTime(2026, 7, 31, 9)),
    _report('yesterday', DateTime(2026, 7, 30, 10)),
    _report('this-week', DateTime(2026, 7, 27, 8)),
    _report('last-week', DateTime(2026, 7, 26, 23, 59)),
    _report('this-month', DateTime(2026, 7, 1, 7)),
    _report('last-month', DateTime(2026, 6, 30, 23, 59)),
  ];

  test('dashboard periods filter reports using inclusive calendar dates', () {
    List<String> ids(String period) => filterDashboardReports(
      reports,
      period: period,
      now: now,
      customStart: DateTime(2026, 7, 26),
      customEnd: DateTime(2026, 7, 30),
    ).map((report) => report.id).toList();

    expect(ids('Hari Ini'), ['today']);
    expect(ids('Minggu Ini'), ['today', 'yesterday', 'this-week']);
    expect(ids('Bulan Ini'), [
      'today',
      'yesterday',
      'this-week',
      'last-week',
      'this-month',
    ]);
    expect(ids('Custom'), ['yesterday', 'this-week', 'last-week']);
  });

  test('latest activity is real, sorted, limited, and status-aware', () {
    final activities = buildDashboardActivities(
      [
        _report(
          'approved',
          DateTime(2026, 7, 31, 11),
          status: QCReportStatus.APPROVED,
        ),
        _report('submitted', DateTime(2026, 7, 31, 10)),
        _report(
          'repair',
          DateTime(2026, 7, 30, 9),
          status: QCReportStatus.NEEDS_FOLLOW_UP,
        ),
      ],
      now: now,
      limit: 2,
    );

    expect(activities.map((activity) => activity.reportId), [
      'approved',
      'submitted',
    ]);
    expect(activities.first.title, startsWith('Admin menyetujui:'));
    expect(activities.first.time, '11:00');
  });
}
