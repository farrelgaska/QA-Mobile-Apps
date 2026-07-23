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

void main() {
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

  test('one failed sample does not enable review request', () async {
    final provider = await _providerWithSamples(5);
    addTearDown(provider.dispose);
    _setSampleStatus(provider, 0, QCSampleEvaluationStatus.outOfStandard);

    expect(provider.failedSampleCount, 1);
    expect(provider.isReviewRequestEligible, isFalse);
    expect(provider.requestReview(), isFalse);
  });

  test('two failed samples enable review regardless of sample count', () async {
    for (final sampleCount in [2, 5]) {
      final provider = await _providerWithSamples(sampleCount);
      _setSampleStatus(provider, 0, QCSampleEvaluationStatus.outOfStandard);
      _setSampleStatus(provider, 1, QCSampleEvaluationStatus.outOfStandard);

      expect(provider.failedSampleCount, 2, reason: '$sampleCount samples');
      expect(
        provider.isReviewRequestEligible,
        isTrue,
        reason: '$sampleCount samples',
      );
      provider.dispose();
    }
  });

  test('three failed samples keep review request enabled', () async {
    final provider = await _providerWithSamples(4);
    addTearDown(provider.dispose);
    for (var index = 0; index < 3; index++) {
      _setSampleStatus(provider, index, QCSampleEvaluationStatus.outOfStandard);
    }

    expect(provider.failedSampleCount, 3);
    expect(provider.isReviewRequestEligible, isTrue);
  });

  test('form remains navigable after review eligibility', () async {
    final provider = await _providerWithSamples(3);
    addTearDown(provider.dispose);
    provider.updateAnswer(0, '10');
    provider.updateAnswer(1, 'Baik');
    _setSampleStatus(provider, 0, QCSampleEvaluationStatus.outOfStandard);
    _setSampleStatus(provider, 1, QCSampleEvaluationStatus.outOfStandard);

    expect(provider.isReviewRequestEligible, isTrue);
    expect(await provider.nextStep(), isNull);
    expect(provider.currentStep, 2);
    await provider.previousStep();
    expect(provider.currentStep, 1);
  });

  test(
    'draft saves derived eligibility and explicit review metadata',
    () async {
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      final api = _FakePersistenceApi();
      final provider = await _providerWithSamples(3, api: api);
      final restored = QCMaterialFormProvider(api: api);
      addTearDown(() {
        provider.dispose();
        restored.dispose();
        state.reports
          ..clear()
          ..addAll(originalReports);
      });
      _setSampleStatus(provider, 0, QCSampleEvaluationStatus.outOfStandard);
      _setSampleStatus(provider, 1, QCSampleEvaluationStatus.outOfStandard);
      final requestedAt = DateTime.utc(2026, 7, 23, 4, 30);

      expect(provider.requestReview(requestedAt: requestedAt), isTrue);
      await provider.persistReport(QCReportStatus.DRAFT);

      final saved = api.savedReport!;
      expect(saved.generalInfo['qcFailedSampleCount'], '2');
      expect(saved.generalInfo['qcReviewRequestEligible'], 'true');
      expect(saved.generalInfo['qcReviewRequested'], 'true');
      expect(
        saved.generalInfo['qcReviewRequestedAt'],
        requestedAt.toIso8601String(),
      );
      expect(
        jsonDecode(saved.generalInfo['qcSampleEvaluationStatuses']!),
        containsPair(provider.samples[0].id, 'OUT_OF_STANDARD'),
      );

      final staleDerivedMetadata = saved.copyWith(
        generalInfo: {
          ...saved.generalInfo,
          'qcSampleEvaluationStatuses': '{}',
          'qcFailedSampleCount': '99',
          'qcReviewRequestEligible': 'false',
        },
      );
      state.reports
        ..removeWhere((report) => report.id == saved.id)
        ..add(staleDerivedMetadata);
      restored.init(
        saved.templateId,
        editReportId: saved.id,
        template: _template(),
      );
      expect(restored.failedSampleCount, 2);
      expect(restored.isReviewRequestEligible, isTrue);
      expect(restored.reviewRequested, isTrue);
      expect(restored.reviewRequestedAt, requestedAt);
      expect(
        restored.reviewRequestedFailedSampleIds,
        provider.samples.take(2).map((sample) => sample.id),
      );
      expect(restored.reviewRequestedFailedSampleNumbers, [1, 2]);
    },
  );

  test(
    'correcting a failed sample removes eligibility before request',
    () async {
      final provider = await _providerWithSamples(3);
      addTearDown(provider.dispose);
      _setSampleStatus(provider, 0, QCSampleEvaluationStatus.outOfStandard);
      _setSampleStatus(provider, 1, QCSampleEvaluationStatus.outOfStandard);
      expect(provider.isReviewRequestEligible, isTrue);

      _setSampleStatus(provider, 1, QCSampleEvaluationStatus.withinStandard);

      expect(provider.failedSampleCount, 1);
      expect(provider.isReviewRequestEligible, isFalse);
      expect(provider.reviewRequested, isFalse);
    },
  );

  test('submitted review request remains after later corrections', () async {
    final provider = await _providerWithSamples(3);
    addTearDown(provider.dispose);
    _setSampleStatus(provider, 0, QCSampleEvaluationStatus.outOfStandard);
    _setSampleStatus(provider, 1, QCSampleEvaluationStatus.outOfStandard);
    expect(provider.requestReview(), isTrue);
    final recordedIds = List<String>.from(
      provider.reviewRequestedFailedSampleIds,
    );

    _setSampleStatus(provider, 1, QCSampleEvaluationStatus.withinStandard);

    expect(provider.failedSampleCount, 1);
    expect(provider.isReviewRequestEligible, isFalse);
    expect(provider.reviewRequested, isTrue);
    expect(provider.reviewRequestedFailedSampleIds, recordedIds);
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

    expect(provider.failedSampleCount, 0);
    expect(
      provider.sampleEvaluationStatus(provider.samples.first),
      QCSampleEvaluationStatus.notEvaluated,
    );
    expect(provider.isReviewRequestEligible, isFalse);
    expect(provider.reviewRequested, isFalse);
  });

  testWidgets('UI shows sample status, warning, and explicit review action', (
    tester,
  ) async {
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
    _fillGeneralInformation(provider, sampleCount: 2);
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    _setSampleStatus(provider, 0, QCSampleEvaluationStatus.outOfStandard);
    _setSampleStatus(provider, 1, QCSampleEvaluationStatus.outOfStandard);
    await tester.pump();

    expect(find.text('Status Sampel: Di Luar Standar'), findsOneWidget);
    expect(
      find.byKey(const Key('qc_material_review_request_card')),
      findsOneWidget,
    );
    final reviewButton = find.byKey(
      const Key('qc_material_request_review_button'),
    );
    expect(reviewButton, findsOneWidget);
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await tester.pump();

    expect(provider.reviewRequested, isTrue);
    expect(find.text('Permintaan review sudah dicatat.'), findsOneWidget);
  });
}
