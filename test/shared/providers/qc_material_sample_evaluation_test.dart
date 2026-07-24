import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/features/qc_material/screens/qc_material_form_screen.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_material_evaluation_model.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/models/qc_report_model.dart';
import 'package:mobile/shared/models/qc_report_sample_model.dart';
import 'package:mobile/shared/providers/qc_material_form_provider.dart';
import 'package:provider/provider.dart';

class _FakePersistenceApi implements QCMaterialPersistenceApi {
  QCReportModel? savedReport;

  @override
  Future<QCEvidenceUploadResult> uploadQCEvidence({
    required XFile file,
    required String reportId,
    required String itemId,
  }) {
    throw UnimplementedError('These tests do not upload photos.');
  }

  @override
  Future<bool> patchReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    savedReport = QCReportModel.fromJson(report.toJson());
    return true;
  }

  @override
  Future<bool> postReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    savedReport = QCReportModel.fromJson(report.toJson());
    return true;
  }
}

QCMaterialTemplate _template() => QCMaterialTemplate(
  id: 'MAT-SAMPLE-EVALUATION',
  name: 'Sample Evaluation',
  code: 'MAT-EVAL',
  description: '',
  checklistItems: [
    QCChecklistItem(
      id: 'dimension',
      label: 'Dimensi',
      category: 'Ukuran',
      inputType: QCInputType.number,
      standardText: '10 mm',
      minValue: 9,
      maxValue: 11,
      required: true,
    ),
    QCChecklistItem(
      id: 'condition',
      label: 'Kondisi',
      category: 'Visual',
      inputType: QCInputType.choice,
      standardText: 'Baik',
      choices: const ['Baik', 'Tidak Baik'],
      required: true,
    ),
    QCChecklistItem(
      id: 'optional-note',
      label: 'Catatan Tambahan',
      category: 'Lainnya',
      inputType: QCInputType.text,
      standardText: '',
      required: false,
    ),
  ],
);

void _fillGeneralInformation(
  QCMaterialFormProvider provider, {
  required int sampleCount,
}) {
  provider.poNumberController.text = 'PO-EVAL';
  provider.poDateController.text = '2026-07-01';
  provider.doNumberController.text = 'DO-EVAL';
  provider.vendorNameController.text = 'Vendor';
  provider.materialIdController.text = 'MAT-SAMPLE-EVALUATION';
  provider.arrivalVolumeController.text = '100';
  provider.samplingVolumeController.text = '$sampleCount';
  provider.sampleCountController.text = '$sampleCount';
  provider.brandNameController.text = 'Brand';
  provider.warehouseLocationController.text = 'Gudang';
  provider.stelVersionController.text = 'STEL-EVAL';
  provider.qaExpiryDateController.text = '2028-12-31';
  provider.tkdnNumberController.text = 'TKDN-EVAL';
  provider.tkdnCertDateController.text = '2026-01-15';
  provider.tkdnValueController.text = '45';
}

Future<QCMaterialFormProvider> _providerWithSamples(
  int sampleCount, {
  QCMaterialPersistenceApi? api,
}) async {
  final provider = QCMaterialFormProvider(api: api)
    ..init('MAT-SAMPLE-EVALUATION', template: _template());
  _fillGeneralInformation(provider, sampleCount: sampleCount);
  expect(await provider.nextStep(), isNull);
  return provider;
}

void _setSampleStatus(
  QCMaterialFormProvider provider,
  int sampleIndex,
  QCSampleEvaluationStatus status,
) {
  for (var answerIndex = 0; answerIndex < 2; answerIndex++) {
    provider.setParameterEvaluationStatus(
      sampleIndex: sampleIndex,
      answerIndex: answerIndex,
      status: status,
    );
  }
}

/// Fills answers and calls nextStep(). When this is the second failed sample,
/// nextStep() will mark it completed and detect isSamplingDecisionRequired,
/// returning null without advancing the step counter. The caller is
/// responsible for recording a decision or asserting the state.
Future<String?> _completeSample(
  QCMaterialFormProvider provider,
  int sampleIndex, {
  required bool failed,
}) async {
  final sample = provider.samples[sampleIndex];
  sample.answers[0].value = '10';
  sample.answers[1].value = 'Baik';
  _setSampleStatus(
    provider,
    sampleIndex,
    QCSampleEvaluationStatus.withinStandard,
  );
  if (failed) {
    provider.setParameterEvaluationStatus(
      sampleIndex: sampleIndex,
      answerIndex: 0,
      status: QCSampleEvaluationStatus.outOfStandard,
    );
  }
  return provider.nextStep();
}

void main() {
  // ── Parameter-level evaluation ─────────────────────────────────────────────

  test('one OUT_OF_STANDARD parameter makes sample OUT_OF_STANDARD', () async {
    final provider = await _providerWithSamples(1);
    addTearDown(provider.dispose);

    provider.setParameterEvaluationStatus(
      sampleIndex: 0,
      answerIndex: 0,
      status: QCSampleEvaluationStatus.outOfStandard,
    );

    expect(
      provider.sampleEvaluationStatus(provider.samples.first),
      QCSampleEvaluationStatus.outOfStandard,
    );
  });

  test(
    'all required parameters WITHIN_STANDARD makes sample conform',
    () async {
      final provider = await _providerWithSamples(1);
      addTearDown(provider.dispose);
      _setSampleStatus(provider, 0, QCSampleEvaluationStatus.withinStandard);

      expect(
        provider.sampleEvaluationStatus(provider.samples.first),
        QCSampleEvaluationStatus.withinStandard,
      );
    },
  );

  test('incomplete required evaluation remains NOT_EVALUATED', () async {
    final provider = await _providerWithSamples(1);
    addTearDown(provider.dispose);
    provider.setParameterEvaluationStatus(
      sampleIndex: 0,
      answerIndex: 0,
      status: QCSampleEvaluationStatus.withinStandard,
    );

    expect(
      provider.sampleEvaluationStatus(provider.samples.first),
      QCSampleEvaluationStatus.notEvaluated,
    );
  });

  test(
    'live input reuses existing numeric and choice evaluation rules',
    () async {
      final provider = await _providerWithSamples(1);
      addTearDown(provider.dispose);

      provider.updateAnswer(0, '12');
      provider.updateAnswer(1, 'Baik');
      expect(
        provider.sampleEvaluationStatus(provider.samples.first),
        QCSampleEvaluationStatus.outOfStandard,
      );

      provider.updateAnswer(0, '10');
      expect(
        provider.sampleEvaluationStatus(provider.samples.first),
        QCSampleEvaluationStatus.withinStandard,
      );
    },
  );

  // ── Threshold: one failure is tolerated ────────────────────────────────────

  test(
    'one failed completed sample does not trigger the warning',
    () async {
      final provider = await _providerWithSamples(3);
      addTearDown(provider.dispose);

      final err = await _completeSample(provider, 0, failed: true);
      expect(err, isNull); // advances to next sample normally

      expect(provider.failedCompletedCount, 1);
      expect(provider.isSamplingDecisionRequired, isFalse);
      expect(provider.isSamplingWarningActive, isFalse);
    },
  );

  // ── Threshold: second failure triggers immediately ─────────────────────────

  test(
    'second failed completed sample triggers the warning immediately',
    () async {
      // 10-sample total: proves no fixed window size is applied.
      final provider = await _providerWithSamples(10);
      addTearDown(provider.dispose);

      await _completeSample(provider, 0, failed: false);
      await _completeSample(provider, 1, failed: true);

      expect(provider.failedCompletedCount, 1);
      expect(provider.isSamplingDecisionRequired, isFalse);

      // Second failure on sample index 2: nextStep stays on same step.
      final err = await _completeSample(provider, 2, failed: true);
      expect(err, isNull);
      expect(provider.isSamplingDecisionRequired, isTrue);
      expect(provider.failedCompletedCount, 2);
    },
  );

  test(
    'warning fires after only two completed samples with a large total count',
    () async {
      // 100-sample total: warning must fire after 2 failures, not after 5 completed.
      final provider = await _providerWithSamples(100);
      addTearDown(provider.dispose);

      await _completeSample(provider, 0, failed: true);
      expect(provider.isSamplingDecisionRequired, isFalse); // only 1 failure

      await _completeSample(provider, 1, failed: true);
      expect(provider.isSamplingDecisionRequired, isTrue);
      expect(provider.failedCompletedCount, 2);
      // Only 2 samples have been completed; fewer than five.
      expect(
        provider.samples
            .where(
              (s) => s.inspectionStatus == QCSampleInspectionStatus.completed,
            )
            .length,
        2,
      );
    },
  );

  // ── STOP behavior ──────────────────────────────────────────────────────────

  test(
    'STOP requires a reason and blocks additional sample navigation',
    () async {
      final provider = await _providerWithSamples(6);
      addTearDown(provider.dispose);

      await _completeSample(provider, 0, failed: true);
      await _completeSample(provider, 1, failed: true); // triggers decision

      expect(provider.isSamplingDecisionRequired, isTrue);

      expect(
        provider.recordSamplingDecision(
          decision: QCMaterialSamplingDecisionType.stop,
          stopReason: '   ',
        ),
        'Alasan penghentian wajib diisi.',
      );
      expect(provider.hasSamplingDecision, isFalse);

      final decidedAt = DateTime.utc(2026, 7, 24, 1);
      expect(
        provider.recordSamplingDecision(
          decision: QCMaterialSamplingDecisionType.stop,
          stopReason: 'Material dikembalikan ke vendor',
          decidedAt: decidedAt,
        ),
        isNull,
      );

      expect(provider.isSamplingStopped, isTrue);
      expect(provider.samplingDecision!.decidedAt, decidedAt);
      expect(provider.samplingDecision!.failedSampleNumbers, [1, 2]);
      expect(await provider.nextStep(), contains('telah dihentikan'));
    },
  );

  // ── CONTINUE behavior ──────────────────────────────────────────────────────

  test(
    'CONTINUE records a decision and permits additional navigation',
    () async {
      final provider = await _providerWithSamples(6);
      addTearDown(provider.dispose);

      await _completeSample(provider, 0, failed: true);
      final stepBeforeSecond = provider.currentStep;
      await _completeSample(provider, 1, failed: true); // triggers decision

      expect(provider.isSamplingDecisionRequired, isTrue);
      // Navigation is temporarily blocked while decision is required
      expect(provider.currentStep, stepBeforeSecond);

      final decidedAt = DateTime.utc(2026, 7, 24, 1, 30);
      expect(
        provider.recordSamplingDecision(
          decision: QCMaterialSamplingDecisionType.continueInspection,
          decidedAt: decidedAt,
        ),
        isNull,
      );
      expect(provider.hasSamplingDecision, isTrue);
      expect(
        provider.samplingDecision!.type,
        QCMaterialSamplingDecisionType.continueInspection,
      );
      expect(provider.samplingDecision!.decidedAt, decidedAt);
      expect(provider.isSamplingDecisionRequired, isFalse);

      expect(await provider.nextStep(), isNull);
      // After CONTINUE, user is permitted to navigate to the next sample
      expect(provider.currentStep, stepBeforeSecond + 1);
    },
  );

  // ── Dialog does not reopen after a decision ────────────────────────────────

  test('decision state prevents the sampling warning from reopening', () async {
    final provider = await _providerWithSamples(6);
    addTearDown(provider.dispose);

    await _completeSample(provider, 0, failed: true);
    await _completeSample(provider, 1, failed: true);
    expect(provider.isSamplingDecisionRequired, isTrue);

    expect(
      provider.recordSamplingDecision(
        decision: QCMaterialSamplingDecisionType.continueInspection,
      ),
      isNull,
    );
    expect(provider.isSamplingDecisionRequired, isFalse);
    expect(
      provider.recordSamplingDecision(
        decision: QCMaterialSamplingDecisionType.stop,
        stopReason: 'Tidak boleh mengganti keputusan',
      ),
      'Keputusan sampling sudah dicatat.',
    );
  });

  // ── Draft / restore ────────────────────────────────────────────────────────

  test('draft save and restore preserves the STOP decision snapshot', () async {
    final state = DummyState();
    final originalReports = List<QCReportModel>.from(state.reports);
    final api = _FakePersistenceApi();
    final provider = await _providerWithSamples(6, api: api);
    final restored = QCMaterialFormProvider(api: api);
    addTearDown(() {
      provider.dispose();
      restored.dispose();
      state.reports
        ..clear()
        ..addAll(originalReports);
    });

    // Complete samples 0 and 1 as failed (triggers decision after sample 1).
    await _completeSample(provider, 0, failed: true);
    await _completeSample(provider, 1, failed: true);

    final decidedAt = DateTime.utc(2026, 7, 24, 2, 15);
    expect(
      provider.recordSamplingDecision(
        decision: QCMaterialSamplingDecisionType.stop,
        stopReason: 'Kemasan rusak pada sampel awal',
        decidedAt: decidedAt,
      ),
      isNull,
    );

    await provider.persistReport(QCReportStatus.DRAFT);
    final saved = api.savedReport!;
    expect(saved.generalInfo[QCMaterialSamplingDecision.decisionKey], 'STOP');

    restored.init(
      saved.templateId,
      editReportId: saved.id,
      template: _template(),
    );
    expect(restored.isSamplingStopped, isTrue);
    expect(restored.samplingDecision!.decidedAt, decidedAt);
    expect(
      restored.samplingDecision!.stopReason,
      'Kemasan rusak pada sampel awal',
    );
    expect(restored.samplingDecision!.failedSampleNumbers, [1, 2]);
    expect(
      restored.samplingDecision!.failedSampleIds,
      provider.samplingDecision!.failedSampleIds,
    );
  });

  test('legacy draft does not synthesize failure or review request', () {
    final state = DummyState();
    final originalReports = List<QCReportModel>.from(state.reports);
    final legacy = QCReportModel(
      id: 'QC-LEGACY-EVALUATION',
      title: 'Legacy Evaluation',
      type: QCType.material,
      status: QCReportStatus.DRAFT,
      staffNote: '',
      templateId: 'MAT-SAMPLE-EVALUATION',
    );
    state.reports
      ..clear()
      ..add(legacy);
    final provider = QCMaterialFormProvider()
      ..init(legacy.templateId, editReportId: legacy.id, template: _template());
    addTearDown(() {
      provider.dispose();
      state.reports
        ..clear()
        ..addAll(originalReports);
    });

    expect(provider.failedCompletedCount, 0);
    expect(
      provider.sampleEvaluationStatus(provider.samples.first),
      QCSampleEvaluationStatus.notEvaluated,
    );
    expect(provider.isSamplingDecisionRequired, isFalse);
    expect(provider.hasSamplingDecision, isFalse);
  });

  // ── UI: dialog offers STOP and CONTINUE ───────────────────────────────────

  testWidgets(
    'UI shows decision dialog when second failed sample is completed',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QCMaterialFormScreen(
            materialId: 'MAT-SAMPLE-EVALUATION',
            template: _template(),
          ),
        ),
      );
      final nextButton = find.byKey(const Key('qc_material_next_button'));
      final provider = Provider.of<QCMaterialFormProvider>(
        tester.element(nextButton),
        listen: false,
      );
      _fillGeneralInformation(provider, sampleCount: 6);
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Mark only the first two samples as out-of-standard and completed.
      for (var index = 0; index < 2; index++) {
        provider.samples[index].answers[0].value = '10';
        provider.samples[index].answers[1].value = 'Baik';
        provider.setParameterEvaluationStatus(
          sampleIndex: index,
          answerIndex: 0,
          status: QCSampleEvaluationStatus.outOfStandard,
        );
        provider.samples[index].inspectionStatus =
            QCSampleInspectionStatus.completed;
      }
      await tester.pump();
      await tester.ensureVisible(nextButton);
      await tester.pump();
      await tester.tap(nextButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Peringatan Sampling Material'), findsOneWidget);
      expect(find.text('Hentikan Pemeriksaan'), findsOneWidget);
      expect(find.text('Lanjutkan Pemeriksaan'), findsOneWidget);
      expect(find.text('Ajukan Review'), findsNothing);

      await tester.tap(
        find.byKey(const Key('qc_material_continue_inspection_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(provider.hasSamplingDecision, isTrue);
      expect(find.text('Peringatan Sampling Material'), findsNothing);
    },
  );
}
