import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/features/qc_material/screens/qc_material_form_screen.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_checklist_answer_model.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/models/qc_report_model.dart';
import 'package:mobile/shared/providers/qc_material_form_provider.dart';
import 'package:provider/provider.dart';

class _FakePersistenceApi implements QCMaterialPersistenceApi {
  QCReportModel? postedReport;
  QCReportModel? patchedReport;

  @override
  Future<QCEvidenceUploadResult> uploadQCEvidence({
    required XFile file,
    required String reportId,
    required String itemId,
  }) {
    throw UnimplementedError('No local upload is used by these tests.');
  }

  @override
  Future<bool> patchReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    patchedReport = QCReportModel.fromJson(report.toJson());
    return true;
  }

  @override
  Future<bool> postReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    postedReport = QCReportModel.fromJson(report.toJson());
    return true;
  }
}

QCMaterialTemplate _template({bool required = false}) => QCMaterialTemplate(
  id: 'MAT-MULTI-STEP',
  name: 'Material Multi Step',
  code: 'MAT-MS-01',
  description: '',
  checklistItems: [
    QCChecklistItem(
      id: 'number',
      label: 'Angka',
      category: 'Test',
      inputType: QCInputType.number,
      standardText: '10',
      required: required,
    ),
    QCChecklistItem(
      id: 'boolean',
      label: 'Boolean',
      category: 'Test',
      inputType: QCInputType.booleanCheck,
      standardText: 'Ya',
      required: required,
    ),
    QCChecklistItem(
      id: 'choice',
      label: 'Pilihan',
      category: 'Test',
      inputType: QCInputType.choice,
      standardText: 'Baik',
      required: required,
    ),
    QCChecklistItem(
      id: 'text',
      label: 'Teks',
      category: 'Test',
      inputType: QCInputType.text,
      standardText: '',
      required: required,
    ),
  ],
);

void _fillValidGeneralInformation(
  QCMaterialFormProvider provider, {
  String sampleCount = '1',
}) {
  provider.poNumberController.text = 'PO-100';
  provider.poDateController.text = '2026-07-01';
  provider.doNumberController.text = 'DO-100';
  provider.vendorNameController.text = 'Vendor A';
  provider.materialIdController.text = 'MAT-MULTI-STEP';
  provider.arrivalVolumeController.text = '100';
  provider.samplingVolumeController.text = '5';
  provider.sampleCountController.text = sampleCount;
  provider.brandNameController.text = 'Brand A';
  provider.warehouseLocationController.text = 'Gudang A';
  provider.stelVersionController.text = 'STEL-01';
  provider.qaExpiryDateController.text = '2028-12-31';
  provider.tkdnNumberController.text = 'TKDN-100';
  provider.tkdnCertDateController.text = '2026-01-15';
  provider.tkdnValueController.text = '42.5';
}

Map<QCMaterialGeneralField, TextEditingController> _requiredControllers(
  QCMaterialFormProvider provider,
) => {
  QCMaterialGeneralField.poNumber: provider.poNumberController,
  QCMaterialGeneralField.poDate: provider.poDateController,
  QCMaterialGeneralField.doNumber: provider.doNumberController,
  QCMaterialGeneralField.vendorName: provider.vendorNameController,
  QCMaterialGeneralField.materialId: provider.materialIdController,
  QCMaterialGeneralField.arrivalVolume: provider.arrivalVolumeController,
  QCMaterialGeneralField.samplingVolume: provider.samplingVolumeController,
  QCMaterialGeneralField.sampleCount: provider.sampleCountController,
  QCMaterialGeneralField.brandName: provider.brandNameController,
  QCMaterialGeneralField.warehouseLocation:
      provider.warehouseLocationController,
  QCMaterialGeneralField.stelVersion: provider.stelVersionController,
  QCMaterialGeneralField.qaExpiryDate: provider.qaExpiryDateController,
  QCMaterialGeneralField.tkdnNumber: provider.tkdnNumberController,
  QCMaterialGeneralField.tkdnCertDate: provider.tkdnCertDateController,
  QCMaterialGeneralField.tkdnValue: provider.tkdnValueController,
};

void main() {
  test('empty Step 1 cannot proceed or resize sample state', () async {
    final provider = QCMaterialFormProvider()
      ..init('MAT-MULTI-STEP', template: _template());
    addTearDown(provider.dispose);
    provider.sampleCountController.text = '3';

    final error = await provider.nextStep();

    expect(error, 'Nomor PO wajib diisi.');
    expect(provider.currentStep, 0);
    expect(provider.samples, hasLength(1));
    expect(provider.sampleCount, 1);
    expect(
      provider.generalFieldError(QCMaterialGeneralField.poNumber),
      'Nomor PO wajib diisi.',
    );
  });

  test('every required general field blocks Step 1 navigation', () async {
    final provider = QCMaterialFormProvider()
      ..init('MAT-MULTI-STEP', template: _template());
    addTearDown(provider.dispose);

    for (final entry in _requiredControllers(provider).entries) {
      _fillValidGeneralInformation(provider);
      entry.value.clear();

      expect(await provider.nextStep(), isNotNull, reason: entry.key.name);
      expect(provider.currentStep, 0, reason: entry.key.name);
      expect(
        provider.generalFieldErrors,
        contains(entry.key),
        reason: entry.key.name,
      );
      expect(
        provider.vendorNameController.text,
        entry.key == QCMaterialGeneralField.vendorName ? '' : 'Vendor A',
      );
    }
  });

  test('invalid numeric fields and sample count block navigation', () async {
    final provider = QCMaterialFormProvider()
      ..init('MAT-MULTI-STEP', template: _template());
    addTearDown(provider.dispose);

    for (final value in ['0', '-1', '1.5', 'abc']) {
      _fillValidGeneralInformation(provider, sampleCount: value);
      expect(await provider.nextStep(), isNotNull, reason: value);
      expect(provider.currentStep, 0);
      expect(provider.samples, hasLength(1));
    }

    _fillValidGeneralInformation(provider);
    provider.arrivalVolumeController.text = 'banyak';
    expect(await provider.nextStep(), contains('angka yang valid'));
    expect(provider.currentStep, 0);

    _fillValidGeneralInformation(provider);
    provider.tkdnValueController.text = '-1';
    expect(await provider.nextStep(), contains('tidak boleh negatif'));
    expect(provider.currentStep, 0);
  });

  test('all required custom location fields block navigation', () async {
    final provider = QCMaterialFormProvider()
      ..init('MAT-MULTI-STEP', template: _template());
    addTearDown(provider.dispose);
    _fillValidGeneralInformation(provider);
    provider.setIsCustomLocation(true);

    expect(await provider.nextStep(), isNotNull);
    expect(
      provider.generalFieldErrors.keys,
      containsAll([
        QCMaterialGeneralField.customLocationName,
        QCMaterialGeneralField.customLocationArea,
        QCMaterialGeneralField.customLocationSegment,
      ]),
    );
    expect(provider.currentStep, 0);
  });

  test(
    'general information survives forward and backward navigation',
    () async {
      final provider = QCMaterialFormProvider()
        ..init('MAT-MULTI-STEP', template: _template());
      addTearDown(provider.dispose);

      _fillValidGeneralInformation(provider, sampleCount: '2');

      expect(await provider.nextStep(), isNull);
      expect(provider.currentStep, 1);
      await provider.previousStep();

      expect(provider.currentStep, 0);
      expect(provider.poNumberController.text, 'PO-100');
      expect(provider.vendorNameController.text, 'Vendor A');
      expect(provider.sampleCount, 2);
    },
  );

  test(
    'sample values, notes, and checklist photos remain isolated by sample',
    () async {
      const sampleOnePhoto =
          'reports/QC-MULTI/checklist/number/123e4567-e89b-42d3-a456-426614174000.jpg';
      const sampleTwoPhoto =
          'reports/QC-MULTI/checklist/number/123e4567-e89b-42d3-a456-426614174001.jpg';
      final provider = QCMaterialFormProvider()
        ..init('MAT-MULTI-STEP', template: _template());
      addTearDown(provider.dispose);
      _fillValidGeneralInformation(provider, sampleCount: '2');
      await provider.nextStep();

      provider.updateAnswer(0, 12.5);
      provider.updateAnswer(1, true);
      provider.updateAnswer(2, 'Baik');
      provider.updateAnswer(3, 'Sampel pertama');
      provider.currentSample!.notesController.text = 'Catatan satu';
      provider.updateSampleNotes('Catatan satu');
      provider.answers[0].photoPaths.add(sampleOnePhoto);
      final firstId = provider.currentSample!.id;

      await provider.nextStep();
      expect(provider.currentSample!.sampleNumber, 2);
      expect(provider.answers.every((answer) => answer.value == ''), isTrue);

      provider.updateAnswer(0, 7);
      provider.updateAnswer(1, false);
      provider.updateAnswer(2, 'Periksa');
      provider.updateAnswer(3, 'Sampel kedua');
      provider.currentSample!.notesController.text = 'Catatan dua';
      provider.updateSampleNotes('Catatan dua');
      provider.answers[0].photoPaths.add(sampleTwoPhoto);
      final secondId = provider.currentSample!.id;

      await provider.previousStep();
      expect(provider.currentSample!.id, firstId);
      expect(provider.answers.map((answer) => answer.value), [
        12.5,
        true,
        'Baik',
        'Sampel pertama',
      ]);
      expect(provider.currentSample!.notesController.text, 'Catatan satu');
      expect(provider.answers[0].photoPaths, [sampleOnePhoto]);

      await provider.nextStep();
      expect(provider.currentSample!.id, secondId);
      expect(provider.answers.map((answer) => answer.value), [
        7,
        false,
        'Periksa',
        'Sampel kedua',
      ]);
      expect(provider.currentSample!.notesController.text, 'Catatan dua');
      expect(provider.answers[0].photoPaths, [sampleTwoPhoto]);
    },
  );

  test('draft saves and restores all ordered samples and current step', () async {
    const firstPhoto =
        'reports/QC-MULTI/checklist/number/223e4567-e89b-42d3-a456-426614174000.jpg';
    const secondPhoto =
        'reports/QC-MULTI/checklist/number/223e4567-e89b-42d3-a456-426614174001.jpg';
    const firstSamplePhoto =
        'reports/QC-MULTI/general/323e4567-e89b-42d3-a456-426614174000.jpg';
    const secondSamplePhoto =
        'reports/QC-MULTI/general/323e4567-e89b-42d3-a456-426614174001.jpg';
    final state = DummyState();
    final originalReports = List<QCReportModel>.from(state.reports);
    final api = _FakePersistenceApi();
    final provider = QCMaterialFormProvider(api: api)
      ..init('MAT-MULTI-STEP', template: _template());
    final restoredProvider = QCMaterialFormProvider(api: api);
    addTearDown(() {
      provider.dispose();
      restoredProvider.dispose();
      state.reports
        ..clear()
        ..addAll(originalReports);
    });

    _fillValidGeneralInformation(provider, sampleCount: '2');
    provider.poNumberController.text = 'PO-DRAFT';
    await provider.nextStep();
    provider.updateAnswer(0, 11.25);
    provider.updateAnswer(1, true);
    provider.updateAnswer(2, 'A');
    provider.updateAnswer(3, 'Teks A');
    provider.currentSample!.notesController.text = 'Catatan A';
    provider.currentSample!.photoPaths.add(firstSamplePhoto);
    provider.answers[0].photoPaths.add(firstPhoto);
    await provider.nextStep();
    provider.updateAnswer(0, 22);
    provider.updateAnswer(1, false);
    provider.updateAnswer(2, 'B');
    provider.updateAnswer(3, 'Teks B');
    provider.currentSample!.notesController.text = 'Catatan B';
    provider.currentSample!.photoPaths.add(secondSamplePhoto);
    provider.answers[0].photoPaths.add(secondPhoto);

    await provider.persistReport(QCReportStatus.DRAFT);

    final saved = api.postedReport!;
    expect(saved.sampleCount, 2);
    expect(saved.samples.map((sample) => sample.sampleNumber), [1, 2]);
    expect(saved.samples[0].checklistAnswers.map((answer) => answer.value), [
      11.25,
      true,
      'A',
      'Teks A',
    ]);
    expect(saved.samples[1].checklistAnswers.map((answer) => answer.value), [
      22,
      false,
      'B',
      'Teks B',
    ]);
    expect(saved.samples[0].checklistAnswers[0].photoPaths, [firstPhoto]);
    expect(saved.samples[1].checklistAnswers[0].photoPaths, [secondPhoto]);
    expect(saved.samples[0].photoPaths, [firstSamplePhoto]);
    expect(saved.samples[1].photoPaths, [secondSamplePhoto]);
    expect(saved.generalInfo['currentStep'], '2');

    restoredProvider.init(
      saved.templateId,
      editReportId: saved.id,
      template: _template(),
    );
    expect(restoredProvider.currentStep, 2);
    expect(
      restoredProvider.samples.map((sample) => sample.id),
      saved.samples.map((sample) => sample.id),
    );
    expect(restoredProvider.currentSample!.notesController.text, 'Catatan B');
    await restoredProvider.previousStep();
    expect(restoredProvider.currentSample!.notesController.text, 'Catatan A');
  });

  test('legacy draft without samples opens as one safe sample', () {
    final state = DummyState();
    final originalReports = List<QCReportModel>.from(state.reports);
    final legacy = QCReportModel(
      id: 'QC-LEGACY-MATERIAL',
      title: 'Legacy',
      type: QCType.material,
      status: QCReportStatus.DRAFT,
      staffNote: '',
      templateId: 'MAT-MULTI-STEP',
      checklistItems: [
        QCChecklistAnswer(
          itemId: 'number',
          value: '15',
          status: QCResultStatus.notFilled,
          photoPaths: [],
          inputType: 'number',
        ),
      ],
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

    expect(provider.sampleCount, 1);
    expect(provider.samples, hasLength(1));
    expect(provider.answers.first.value, '15');
    expect(provider.answers.first.evaluationStatus, 'NOT_EVALUATED');
  });

  test('current-step validation does not validate future samples', () async {
    final provider = QCMaterialFormProvider()
      ..init('MAT-MULTI-STEP', template: _template(required: true));
    addTearDown(provider.dispose);
    _fillValidGeneralInformation(provider, sampleCount: '2');
    await provider.nextStep();

    provider.updateAnswer(0, '10');
    provider.updateAnswer(1, 'Ya');
    provider.updateAnswer(2, 'Baik');
    provider.updateAnswer(3, 'Lengkap');

    expect(provider.validateCurrentStep(), isNull);
    expect(provider.validateForm(), contains('Sampel 2'));
  });

  test('rapid repeated Next only advances one step', () async {
    final provider = QCMaterialFormProvider()
      ..init('MAT-MULTI-STEP', template: _template());
    addTearDown(provider.dispose);
    _fillValidGeneralInformation(provider, sampleCount: '2');

    final first = provider.nextStep();
    final repeated = provider.nextStep();
    await Future.wait([first, repeated]);

    expect(provider.currentStep, 1);
    expect(provider.samples, hasLength(2));
  });

  test('incomplete Step 1 can still be saved as a draft', () async {
    final api = _FakePersistenceApi();
    final provider = QCMaterialFormProvider(api: api)
      ..init('MAT-MULTI-STEP', template: _template());
    addTearDown(provider.dispose);
    provider.poNumberController.text = 'PO-INCOMPLETE';

    await provider.persistReport(QCReportStatus.DRAFT);

    expect(api.postedReport, isNotNull);
    expect(api.postedReport!.status, QCReportStatus.DRAFT);
    expect(api.postedReport!.generalInfo['poNumber'], 'PO-INCOMPLETE');
    expect(provider.currentStep, 0);
  });

  testWidgets('empty Step 1 stays visible and shows field errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QCMaterialFormScreen(
          materialId: 'MAT-MULTI-STEP',
          template: _template(),
        ),
      ),
    );

    final nextButton = find.byKey(const Key('qc_material_next_button'));
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.text('Informasi Umum Pengadaan'), findsOneWidget);
    expect(find.text('Nomor PO wajib diisi.'), findsWidgets);
    expect(find.byKey(const Key('qc_material_submit_button')), findsNothing);
  });

  testWidgets('submit action is built only on the final sample step', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QCMaterialFormScreen(
          materialId: 'MAT-MULTI-STEP',
          template: _template(),
        ),
      ),
    );

    expect(find.byKey(const Key('qc_material_next_button')), findsOneWidget);
    expect(find.byKey(const Key('qc_material_submit_button')), findsNothing);

    final nextButton = find.byKey(const Key('qc_material_next_button'));
    final provider = Provider.of<QCMaterialFormProvider>(
      tester.element(nextButton),
      listen: false,
    );
    _fillValidGeneralInformation(provider);
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('qc_material_submit_button')), findsOneWidget);
    expect(find.text('Sampel 1 dari 1'), findsOneWidget);
  });
}
