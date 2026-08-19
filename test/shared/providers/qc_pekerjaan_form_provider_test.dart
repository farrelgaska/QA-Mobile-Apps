import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_evidence_capture_metadata.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/shared/models/checklist_item_model.dart';
import 'package:mobile/shared/models/pekerjaan_model.dart';
import 'package:mobile/shared/models/qc_checklist_answer_model.dart';
import 'package:mobile/shared/models/qc_report_model.dart';
import 'package:mobile/shared/models/template_choice_option.dart';
import 'package:mobile/shared/providers/qc_pekerjaan_form_provider.dart';
import 'package:mobile/shared/services/qc_capture_location_service.dart';
import 'package:mobile/shared/services/qc_photo_processor.dart';
import 'package:mobile/shared/utils/qc_photo_validation.dart';

class _FailingPhotoProcessor implements QCPhotoProcessor {
  final Object error;

  _FailingPhotoProcessor(this.error);

  @override
  Future<QCProcessedPhoto> process(
    XFile photo, {
    QCEvidenceCaptureMetadata? captureMetadata,
  }) =>
      Future.error(error);

  @override
  Future<void> deleteGeneratedFile(XFile photo) async {}
}

class _ControlledPhotoProcessor implements QCPhotoProcessor {
  final Completer<QCProcessedPhoto> completer = Completer<QCProcessedPhoto>();
  QCEvidenceCaptureMetadata? receivedCaptureMetadata;

  @override
  Future<QCProcessedPhoto> process(
    XFile photo, {
    QCEvidenceCaptureMetadata? captureMetadata,
  }) {
    receivedCaptureMetadata = captureMetadata;
    return completer.future;
  }

  @override
  Future<void> deleteGeneratedFile(XFile photo) async {}
}

class _AvailableLocationService implements QCCaptureLocationService {
  @override
  Future<QCCaptureLocationResult> captureLocation() async {
    return const QCCaptureLocationResult.available(
      latitude: -6.2,
      longitude: 106.816666,
      accuracyMeters: 4.5,
      locationLabel: 'Jakarta',
    );
  }
}

void main() {
  test(
    'pekerjaan photo capture uses camera and rejects processing failure',
    () async {
      ImageSource? requestedSource;
      final oversizedPhoto = XFile.fromData(
        Uint8List.fromList([1]),
        name: 'oversized-pekerjaan.jpg',
        mimeType: 'image/jpeg',
      );
      final template = PekerjaanModel(
        id: 'WRK-PHOTO-VALIDATION',
        name: 'Photo validation',
        segment: WorkSegment.construction,
        description: '',
        checklistItems: [
          ChecklistItemModel(
            id: 'photo-1',
            title: 'Dokumentasi',
            inputType: InputType.text,
            standard: 'Foto lapangan',
            requiredPhoto: true,
          ),
        ],
        status: 'Aktif',
      );
      final provider = QCPekerjaanFormProvider(
        photoPicker: (source) async {
          requestedSource = source;
          return oversizedPhoto;
        },
        photoProcessor: _FailingPhotoProcessor(
          const QCPhotoProcessingException(),
        ),
        captureLocationService: _AvailableLocationService(),
      )..init(template);
      addTearDown(provider.dispose);

      final result = await provider.addPhoto(0);

      expect(requestedSource, ImageSource.camera);
      expect(result, PhotoAddResult.fileTooLarge);
      expect(provider.pendingItemPhotos[0], isEmpty);
      expect(provider.pendingItemPhotoBytes[0], isEmpty);
      expect(qcPhotoTooLargeMessage, contains('2 MB'));
    },
  );

  test(
    'pekerjaan exposes preview while processing and blocks persistence',
    () async {
      final capturedBytes = Uint8List.fromList([1, 2, 3, 4]);
      final captured = XFile.fromData(
        capturedBytes,
        name: 'capture.jpg',
        mimeType: 'image/jpeg',
      );
      final processor = _ControlledPhotoProcessor();
      final template = PekerjaanModel(
        id: 'WRK-PROCESSING',
        name: 'Processing preview',
        segment: WorkSegment.construction,
        description: '',
        checklistItems: [
          ChecklistItemModel(
            id: 'photo-1',
            title: 'Dokumentasi',
            inputType: InputType.text,
            standard: 'Foto lapangan',
            requiredPhoto: true,
          ),
        ],
        status: 'Aktif',
      );
      final provider = QCPekerjaanFormProvider(
        photoPicker: (_) async => captured,
        photoProcessor: processor,
        captureLocationService: _AvailableLocationService(),
        clock: () => DateTime(2026, 7, 31, 9, 15, 30),
      )..init(template);
      addTearDown(provider.dispose);

      final addFuture = provider.addPhoto(0);
      await Future<void>.delayed(Duration.zero);

      expect(provider.processingItemPhotos[0], hasLength(1));
      expect(provider.processingItemPhotos[0].single.canPreviewSource, isTrue);
      expect(provider.pendingItemPhotos[0], isEmpty);
      provider.updateResult(0, 'Masih dapat diedit');
      expect(provider.itemResults[0], 'Masih dapat diedit');
      expect(provider.validateForm(), qcPhotoProcessingMessage);
      await expectLater(
        provider.persistReport(QCReportStatus.DRAFT),
        throwsA(
          isA<ReportPersistenceException>().having(
            (error) => error.message,
            'message',
            qcPhotoProcessingMessage,
          ),
        ),
      );

      processor.completer.complete(
        QCProcessedPhoto(
          file: captured,
          bytes: capturedBytes,
          isGenerated: false,
        ),
      );

      expect(await addFuture, PhotoAddResult.added);
      expect(processor.receivedCaptureMetadata?.latitude, -6.2);
      expect(processor.receivedCaptureMetadata?.longitude, 106.816666);
      expect(
        processor.receivedCaptureMetadata?.capturedAt,
        startsWith('2026-07-31T09:15:30'),
      );
      expect(provider.processingItemPhotos[0], isEmpty);
      expect(provider.pendingItemPhotos[0], [same(captured)]);
      expect(provider.pendingItemPhotoBytes[0], [capturedBytes]);
    },
  );

  test('selected backend WORK template is used without dummy lookup', () {
    final selected = PekerjaanModel(
      id: 'WRK-BACKEND-1',
      formCode: 'WORK-01',
      name: 'Backend Work',
      segment: WorkSegment.construction,
      description: 'From API',
      checklistItems: const [],
      status: 'Aktif',
    );
    final provider = QCPekerjaanFormProvider();

    provider.init(selected);

    expect(identical(provider.pekerjaan, selected), isTrue);
    expect(provider.pekerjaan.id, 'WRK-BACKEND-1');
    provider.dispose();
  });

  test('draft restores number, text, choice, and uploaded object paths', () {
    const objectPath =
        'reports/QC-WRK-DRAFT/checklist/choice-1/362a1d19-23cf-4950-9671-41e1293d68f2.jpg';
    final template = PekerjaanModel(
      id: 'WRK-DRAFT-TEMPLATE',
      formCode: 'WORK-DRAFT',
      name: 'Draft Work',
      segment: WorkSegment.construction,
      description: 'Draft restoration test',
      checklistItems: [
        ChecklistItemModel(
          id: 'number-1',
          title: 'Nilai angka',
          inputType: InputType.number,
          standard: '4.2',
          requiredPhoto: false,
        ),
        ChecklistItemModel(
          id: 'text-1',
          title: 'Catatan teks',
          inputType: InputType.text,
          standard: 'Harus lengkap',
          requiredPhoto: false,
        ),
        ChecklistItemModel(
          id: 'choice-1',
          title: 'Kondisi',
          inputType: InputType.choice,
          standard: 'Pilih kondisi',
          requiredPhoto: true,
          choiceOptions: [
            const TemplateChoiceOption(
              id: 'pass',
              label: 'Sudah Rapi',
              value: 'PASS',
              outcome: 'PASS',
              position: 0,
            ),
            const TemplateChoiceOption(
              id: 'fail',
              label: 'Perlu Perbaikan',
              value: 'FAIL',
              outcome: 'FAIL',
              position: 1,
            ),
          ],
        ),
      ],
      status: 'Aktif',
    );
    final report = QCReportModel(
      id: 'QC-WRK-DRAFT-RESTORE-TEST',
      title: 'Draft Work',
      type: QCType.pekerjaan,
      status: QCReportStatus.DRAFT,
      staffNote: '',
      templateId: template.id,
      checklistItems: [
        QCChecklistAnswer(
          itemId: 'number-1',
          value: '4.2',
          status: QCResultStatus.notFilled,
          photoPaths: [],
        ),
        QCChecklistAnswer(
          itemId: 'text-1',
          value: 'Teks tersimpan',
          status: QCResultStatus.notFilled,
          photoPaths: [],
        ),
        QCChecklistAnswer(
          itemId: 'choice-1',
          value: 'PASS',
          status: QCResultStatus.notFilled,
          photoPaths: [objectPath],
        ),
      ],
    );
    final state = DummyState();
    state.reports.add(report);
    final provider = QCPekerjaanFormProvider();

    addTearDown(() {
      provider.dispose();
      state.reports.removeWhere((item) => item.id == report.id);
    });

    provider.init(template, editReportId: report.id);

    expect(provider.itemResults, ['4.2', 'Teks tersimpan', 'PASS']);
    expect(provider.itemPhotos[2], [objectPath]);
    expect(
      provider.pendingItemPhotos.every((photos) => photos.isEmpty),
      isTrue,
    );
  });

  test('FAIL choice requires issue and PASS clears it', () {
    final template = PekerjaanModel(
      id: 'WRK-CHOICE-VALIDATION',
      name: 'Choice validation',
      segment: WorkSegment.construction,
      description: '',
      checklistItems: [
        ChecklistItemModel(
          id: 'choice',
          title: 'Kondisi',
          inputType: InputType.choice,
          standard: 'Harus rapi',
          requiredPhoto: false,
          choiceOptions: const [
            TemplateChoiceOption(
              id: 'pass',
              label: 'Rapi',
              value: 'CUSTOM_PASS',
              outcome: 'PASS',
              position: 0,
            ),
            TemplateChoiceOption(
              id: 'fail',
              label: 'Berantakan',
              value: 'CUSTOM_FAIL',
              outcome: 'FAIL',
              position: 1,
            ),
          ],
        ),
      ],
      status: 'Aktif',
    );
    final provider = QCPekerjaanFormProvider()..init(template);
    addTearDown(provider.dispose);
    provider.areaController.text = 'Area A';
    provider.locationDetailController.text = 'Titik 1';
    provider.mitraController.text = 'Mitra A';

    provider.updateResult(0, 'CUSTOM_FAIL');
    // Ensure status does not change to perluDilengkapi so that UI still recognizes it as a FAIL
    expect(provider.itemStatuses[0], ChecklistStatus.tidakSesuai);
    expect(provider.itemWarnings[0], 'Keterangan masalah wajib diisi');
    expect(provider.validateForm(), contains('keterangan masalah'));

    provider.updateIssueNote(0, 'Kondisi berantakan');
    expect(provider.validateForm(), isNull);

    provider.updateResult(0, 'CUSTOM_PASS');
    expect(provider.itemIssues.single, isEmpty);
    expect(provider.validateForm(), isNull);
  });

  test('pekerjaan uses two validated form steps', () {
    final template = PekerjaanModel(
      id: 'WRK-TWO-STEP',
      name: 'Two step work',
      segment: WorkSegment.construction,
      description: '',
      checklistItems: const [],
      status: 'Aktif',
    );
    final provider = QCPekerjaanFormProvider()..init(template);
    addTearDown(provider.dispose);

    expect(provider.currentStep, 0);
    expect(provider.goToChecklistStep(), 'Area / zona kerja wajib diisi.');

    provider.areaController.text = 'Area A';
    provider.locationDetailController.text = 'Titik 1';
    provider.mitraController.text = 'Mitra A';

    expect(provider.goToChecklistStep(), isNull);
    expect(provider.currentStep, 1);
    expect(provider.isChecklistStep, isTrue);

    provider.goToInformationStep();
    expect(provider.currentStep, 0);
    expect(provider.isInformationStep, isTrue);
  });
}
