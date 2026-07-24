import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/features/reports/screens/report_detail_screen.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_checklist_answer_model.dart';
import 'package:mobile/shared/models/qc_material_evaluation_model.dart';
import 'package:mobile/shared/models/qc_report_model.dart';
import 'package:mobile/shared/models/qc_report_sample_model.dart';

void main() {
  QCChecklistAnswer answer({
    required String itemId,
    required String paramName,
    required String standard,
    required String value,
    List<String> photos = const [],
    String? note,
  }) {
    return QCChecklistAnswer(
      itemId: itemId,
      value: value,
      status: QCResultStatus.notFilled,
      photoPaths: photos,
      paramName: paramName,
      standardText: standard,
      inputType: 'number',
      issueNote: note,
    );
  }

  QCReportSample sample({
    required int sampleNumber,
    required List<QCChecklistAnswer> answers,
    String notes = '',
    List<String> photos = const [],
  }) {
    final now = DateTime.now();
    return QCReportSample(
      id: 'report-sample-$sampleNumber',
      sampleNumber: sampleNumber,
      inspectionStatus: QCSampleInspectionStatus.completed,
      checklistAnswers: answers,
      notes: notes,
      photoPaths: photos,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('one persisted sample renders exactly one sample section', (
    tester,
  ) async {
    final state = DummyState();
    final originalReports = List<QCReportModel>.from(state.reports);
    addTearDown(() {
      state.reports
        ..clear()
        ..addAll(originalReports);
    });

    final singleSampleReport = QCReportModel(
      id: 'QC-MAT-SINGLE-01',
      title: 'Kabel UTP Cat6',
      type: QCType.material,
      status: QCReportStatus.SUBMITTED,
      staffNote: '',
      sampleCount: 5,
      samples: [
        sample(
          sampleNumber: 1,
          answers: [
            answer(
              itemId: 'resistance',
              paramName: 'Resistansi Sinyal',
              standard: '100 Ohm',
              value: '98',
            ),
          ],
        ),
      ],
    );

    state.reports
      ..clear()
      ..add(singleSampleReport);

    await tester.pumpWidget(
      const MaterialApp(home: ReportDetailScreen(reportId: 'QC-MAT-SINGLE-01')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sampel 1'), findsOneWidget);
    expect(find.text('Sampel 2'), findsNothing);
    expect(find.text('Sampel 3'), findsNothing);
    expect(find.text('Resistansi Sinyal'), findsOneWidget);
    expect(find.text('98'), findsOneWidget);
  });

  testWidgets(
    'multiple persisted samples render separately in order without leaking data',
    (tester) async {
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      addTearDown(() {
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      final multiSampleReport = QCReportModel(
        id: 'QC-MAT-MULTI-02',
        title: 'Tiang Besi 7m',
        type: QCType.material,
        status: QCReportStatus.SUBMITTED,
        staffNote: '',
        sampleCount: 3,
        samples: [
          sample(
            sampleNumber: 1,
            answers: [
              answer(
                itemId: 'diameter',
                paramName: 'Diameter Tiang',
                standard: '140 mm',
                value: '142',
              ),
            ],
            notes: 'Catatan Sampel Pertama',
            photos: ['reports/QC-MAT-MULTI-02/checklist/dim/photo1.jpg'],
          ),
          sample(
            sampleNumber: 2,
            answers: [
              answer(
                itemId: 'diameter',
                paramName: 'Diameter Tiang',
                standard: '140 mm',
                value: '138',
              ),
            ],
            notes: 'Catatan Sampel Kedua',
            photos: ['reports/QC-MAT-MULTI-02/checklist/dim/photo2.jpg'],
          ),
        ],
      );

      state.reports
        ..clear()
        ..add(multiSampleReport);

      await tester.pumpWidget(
        const MaterialApp(
          home: ReportDetailScreen(reportId: 'QC-MAT-MULTI-02'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sampel 1'), findsOneWidget);
      expect(find.text('Sampel 2'), findsOneWidget);
      expect(find.text('Sampel 3'), findsNothing);

      expect(find.text('Catatan Sampel Pertama'), findsOneWidget);
      expect(find.text('Catatan Sampel Kedua'), findsOneWidget);
      expect(find.text('142'), findsOneWidget);
      expect(find.text('138'), findsOneWidget);

      final section1 = tester.getTopLeft(find.text('Sampel 1')).dy;
      final section2 = tester.getTopLeft(find.text('Sampel 2')).dy;
      expect(section1, lessThan(section2));
    },
  );

  testWidgets(
    'stopped report displays only persisted samples and STOP decision reason',
    (tester) async {
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      addTearDown(() {
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      final genInfo = <String, String>{};
      final decision = QCMaterialSamplingDecision(
        type: QCMaterialSamplingDecisionType.stop,
        decidedAt: DateTime.utc(2026, 7, 24, 10, 0),
        stopReason: 'Cacat fisik retak pada 2 sampel',
        failedSampleIds: const ['sample-1', 'sample-2'],
        failedSampleNumbers: const [1, 2],
      );
      decision.writeToGeneralInfo(genInfo);

      final stoppedReport = QCReportModel(
        id: 'QC-MAT-STOPPED-03',
        title: 'Splicing Closure',
        type: QCType.material,
        status: QCReportStatus.NEEDS_FOLLOW_UP,
        staffNote: '',
        sampleCount: 6,
        generalInfo: genInfo,
        samples: [
          sample(
            sampleNumber: 1,
            answers: [
              answer(
                itemId: 'seal',
                paramName: 'Kekedapan Air',
                standard: 'Kedap',
                value: 'Bocor',
              ),
            ],
          ),
          sample(
            sampleNumber: 2,
            answers: [
              answer(
                itemId: 'seal',
                paramName: 'Kekedapan Air',
                standard: 'Kedap',
                value: 'Bocor',
              ),
            ],
          ),
        ],
      );

      state.reports
        ..clear()
        ..add(stoppedReport);

      await tester.pumpWidget(
        const MaterialApp(
          home: ReportDetailScreen(reportId: 'QC-MAT-STOPPED-03'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pemeriksaan Dihentikan'), findsOneWidget);
      expect(
        find.text('Alasan Penghentian: Cacat fisik retak pada 2 sampel'),
        findsOneWidget,
      );
      expect(find.text('Sampel 1'), findsOneWidget);
      expect(find.text('Sampel 2'), findsOneWidget);
      expect(find.text('Sampel 3'), findsNothing);
      expect(find.text('Sampel 6'), findsNothing);
    },
  );

  testWidgets(
    'legacy material report without multi-sample list renders single checklist',
    (tester) async {
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      addTearDown(() {
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      final legacyReport = QCReportModel(
        id: 'QC-MAT-LEGACY-04',
        title: 'Kabel Fiber Optic',
        type: QCType.material,
        status: QCReportStatus.SUBMITTED,
        staffNote: '',
        checklistItems: [
          answer(
            itemId: 'attenuation',
            paramName: 'Redaman Fiber',
            standard: '0.35 dB/km',
            value: '0.32',
          ),
        ],
      );

      state.reports
        ..clear()
        ..add(legacyReport);

      await tester.pumpWidget(
        const MaterialApp(
          home: ReportDetailScreen(reportId: 'QC-MAT-LEGACY-04'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hasil Checklist Parameter'), findsOneWidget);
      expect(find.text('Redaman Fiber'), findsOneWidget);
      expect(find.text('0.32'), findsOneWidget);
      expect(find.text('Sampel 1'), findsNothing);
    },
  );

  testWidgets('QC Pekerjaan detail behavior remains unchanged', (tester) async {
    final state = DummyState();
    final originalReports = List<QCReportModel>.from(state.reports);
    addTearDown(() {
      state.reports
        ..clear()
        ..addAll(originalReports);
    });

    final workReport = QCReportModel(
      id: 'QC-WORK-05',
      title: 'Pemasangan ODP',
      type: QCType.pekerjaan,
      status: QCReportStatus.SUBMITTED,
      staffNote: '',
      checklistItems: [
        answer(
          itemId: 'grounding',
          paramName: 'Grounding ODP',
          standard: '< 5 Ohm',
          value: '3.2',
        ),
      ],
    );

    state.reports
      ..clear()
      ..add(workReport);

    await tester.pumpWidget(
      const MaterialApp(home: ReportDetailScreen(reportId: 'QC-WORK-05')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detail Laporan'), findsOneWidget);
    expect(find.text('QC Pekerjaan'), findsOneWidget);
    expect(find.text('Hasil Checklist Parameter'), findsOneWidget);
    expect(find.text('Grounding ODP'), findsOneWidget);
    expect(find.text('3.2'), findsOneWidget);
    expect(find.text('Sampel 1'), findsNothing);
    expect(
      find.byKey(const Key('qc_material_stop_decision_banner')),
      findsNothing,
    );
  });
}
