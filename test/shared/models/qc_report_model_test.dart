import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_checklist_answer_model.dart';
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

  test('Staff evaluation round-trips independently from Admin evaluation', () {
    final report = QCReportModel(
      id: 'report-staff-evaluation',
      title: 'Inspeksi',
      type: QCType.material,
      status: QCReportStatus.SUBMITTED,
      staffNote: '',
      checklistItems: [
        QCChecklistAnswer(
          itemId: 'dimension',
          value: '12',
          status: QCResultStatus.fail,
          issueNote: 'Melebihi batas',
          photoPaths: const ['reports/report/checklist/item/photo.jpg'],
          adminNote: '',
        ),
      ],
    );

    final wire = report.toJson();
    final wireItem = (wire['checklist_items'] as List<dynamic>).single
        as Map<String, dynamic>;
    expect(wireItem['staff_evaluation'], 'OUT_OF_STANDARD');
    expect(wireItem['admin_evaluation'], 'NEEDS_REVIEW');

    final restored = QCReportModel.fromJson(wire);
    expect(restored.checklistItems.single.status, QCResultStatus.fail);
    expect(restored.checklistItems.single.adminNote, isEmpty);
    expect(restored.checklistItems.single.issueNote, 'Melebihi batas');
  });
}
