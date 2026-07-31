import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_report_model.dart';

void main() {
  test('submitted_at is serialized as an explicit UTC timestamp', () {
    final submittedAt = DateTime(2026, 7, 31, 9, 30);
    final report = QCReportModel(
      id: 'report-1',
      title: 'Inspeksi Lapangan',
      type: QCType.pekerjaan,
      status: QCReportStatus.SUBMITTED,
      staffNote: '',
      submittedAt: submittedAt,
    );

    final serialized = report.toJson()['submitted_at'] as String;

    expect(serialized, submittedAt.toUtc().toIso8601String());
    expect(serialized, endsWith('Z'));
    expect(DateTime.parse(serialized), submittedAt.toUtc());
  });
}
