import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_evidence_capture_metadata.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/models/qc_report_model.dart';
import 'package:mobile/shared/providers/qc_material_form_provider.dart';
import 'package:mobile/shared/services/qc_photo_processor.dart';

class _UploadCall {
  final String fileName;
  final String itemId;
  final Uint8List bytes;

  const _UploadCall({
    required this.fileName,
    required this.itemId,
    required this.bytes,
  });
}

class _ConcurrentPersistenceApi implements QCMaterialPersistenceApi {
  final Set<int> failOncePhotoNumbers;
  final Completer<void>? uploadGate;
  final List<_UploadCall> uploadCalls = [];
  final Map<String, int> uploadAttemptsByFileName = {};
  int activeUploads = 0;
  int maximumActiveUploads = 0;
  int postCalls = 0;
  int patchCalls = 0;
  QCReportModel? persistedReport;

  _ConcurrentPersistenceApi({
    Set<int> failOncePhotoNumbers = const {},
    this.uploadGate,
  }) : failOncePhotoNumbers = Set<int>.from(failOncePhotoNumbers);

  @override
  Future<QCEvidenceUploadResult> uploadQCEvidence({
    required XFile file,
    required String reportId,
    required String itemId,
    Uint8List? bytes,
  }) async {
    if (bytes == null) {
      throw StateError('Retained processed bytes were not supplied.');
    }

    final fileName = RegExp(r'photo-\d+\.jpg').firstMatch(file.name)!.group(0)!;
    uploadCalls.add(
      _UploadCall(fileName: fileName, itemId: itemId, bytes: bytes),
    );
    uploadAttemptsByFileName.update(
      fileName,
      (attempts) => attempts + 1,
      ifAbsent: () => 1,
    );
    activeUploads++;
    maximumActiveUploads = activeUploads > maximumActiveUploads
        ? activeUploads
        : maximumActiveUploads;

    try {
      await uploadGate?.future;
      final photoNumber = _photoNumber(fileName);
      if (failOncePhotoNumbers.contains(photoNumber)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        failOncePhotoNumbers.remove(photoNumber);
        throw const ApiRequestException('Upload foto gagal untuk pengujian.');
      }

      final delay = switch (photoNumber % 3) {
        0 => 30,
        1 => 20,
        _ => 10,
      };
      await Future<void>.delayed(Duration(milliseconds: delay));
      return QCEvidenceUploadResult(
        objectPath: _objectPath(
          reportId: reportId,
          itemId: itemId,
          photoNumber: photoNumber,
        ),
        mimeType: 'image/jpeg',
        size: bytes.length,
      );
    } finally {
      activeUploads--;
    }
  }

  @override
  Future<bool> patchReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    patchCalls++;
    persistedReport = QCReportModel.fromJson(report.toJson());
    return true;
  }

  @override
  Future<bool> postReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    postCalls++;
    persistedReport = QCReportModel.fromJson(report.toJson());
    return true;
  }
}

class _SubmitGuardPhotoProcessor implements QCPhotoProcessor {
  int processCalls = 0;

  @override
  Future<QCProcessedPhoto> process(
    XFile photo, {
    QCEvidenceCaptureMetadata? captureMetadata,
  }) {
    processCalls++;
    throw StateError('Submission must not process captured photos again.');
  }

  @override
  Future<void> deleteGeneratedFile(XFile photo) async {}
}

QCMaterialTemplate _template() => QCMaterialTemplate(
  id: 'MAT-UPLOAD-CONCURRENCY',
  name: 'Material upload concurrency',
  code: 'MAT-UPLOAD',
  description: '',
  checklistItems: [
    QCChecklistItem(
      id: 'visual-item',
      label: 'Visual',
      category: 'Visual',
      inputType: QCInputType.text,
      standardText: '',
      required: false,
    ),
    QCChecklistItem(
      id: 'dimension-item',
      label: 'Dimensi',
      category: 'Dimensi',
      inputType: QCInputType.number,
      standardText: '',
      required: false,
    ),
  ],
);

void _fillGeneralInformation(
  QCMaterialFormProvider provider, {
  int sampleCount = 4,
}) {
  provider.poNumberController.text = 'PO-UPLOAD';
  provider.poDateController.text = '2026-07-27';
  provider.doNumberController.text = 'DO-UPLOAD';
  provider.vendorNameController.text = 'Vendor';
  provider.materialIdController.text = 'MAT-UPLOAD-CONCURRENCY';
  provider.arrivalVolumeController.text = '100';
  provider.samplingVolumeController.text = '$sampleCount';
  provider.sampleCountController.text = '$sampleCount';
  provider.brandNameController.text = 'Brand';
  provider.warehouseLocationController.text = 'Warehouse';
  provider.stelVersionController.text = 'STEL';
  provider.qaExpiryDateController.text = '2028-12-31';
  provider.tkdnNumberController.text = 'TKDN';
  provider.tkdnCertDateController.text = '2026-01-15';
  provider.tkdnValueController.text = '45';
}

Future<QCMaterialFormProvider> _providerWithSamples(
  _ConcurrentPersistenceApi api, {
  int sampleCount = 4,
  QCPhotoProcessor? photoProcessor,
}) async {
  final template = _template();
  final provider = QCMaterialFormProvider(
    api: api,
    photoProcessor: photoProcessor,
  )..init(template.id, template: template);
  _fillGeneralInformation(provider, sampleCount: sampleCount);
  expect(await provider.nextStep(), isNull);
  expect(provider.samples, hasLength(sampleCount));
  return provider;
}

List<List<List<String>>> _addPendingPhotos(
  QCMaterialFormProvider provider, {
  int photosPerItem = 4,
}) {
  var photoNumber = 0;
  final expectedPaths = <List<List<String>>>[];
  for (
    var sampleIndex = 0;
    sampleIndex < provider.samples.length;
    sampleIndex++
  ) {
    final expectedByItem = <List<String>>[];
    for (
      var itemIndex = 0;
      itemIndex < provider.template.checklistItems.length;
      itemIndex++
    ) {
      final expectedForItem = <String>[];
      for (var photoIndex = 0; photoIndex < photosPerItem; photoIndex++) {
        final fileName = _photoFileName(photoNumber);
        final bytes = Uint8List.fromList([
          sampleIndex,
          itemIndex,
          photoIndex,
          photoNumber,
        ]);
        final photo = XFile(
          'Z:/missing-qc-evidence/$fileName',
          name: fileName,
          mimeType: 'image/jpeg',
          length: bytes.length,
        );
        provider.samples[sampleIndex].localItemPhotos[itemIndex].add(photo);
        provider.samples[sampleIndex].localItemPhotoBytes[itemIndex].add(bytes);
        expectedForItem.add(
          _objectPath(
            reportId: provider.reportId,
            itemId: provider.template.checklistItems[itemIndex].id,
            photoNumber: photoNumber,
          ),
        );
        photoNumber++;
      }
      expectedByItem.add(expectedForItem);
    }
    expectedPaths.add(expectedByItem);
  }
  return expectedPaths;
}

String _photoFileName(int photoNumber) =>
    'photo-${photoNumber.toString().padLeft(3, '0')}.jpg';

int _photoNumber(String fileName) =>
    int.parse(RegExp(r'photo-(\d+)\.jpg').firstMatch(fileName)!.group(1)!);

String _objectPath({
  required String reportId,
  required String itemId,
  required int photoNumber,
}) {
  final suffix = photoNumber.toRadixString(16).padLeft(12, '0');
  return 'reports/$reportId/checklist/$itemId/'
      '00000000-0000-4000-8000-$suffix.jpg';
}

List<List<List<String>>> _persistedPaths(QCReportModel report) => report.samples
    .map(
      (sample) => sample.checklistAnswers
          .map((answer) => answer.photoPaths)
          .toList(growable: false),
    )
    .toList(growable: false);

void main() {
  final state = DummyState();
  late List<QCReportModel> originalReports;

  setUp(() {
    originalReports = List<QCReportModel>.from(state.reports);
  });

  tearDown(() {
    state.reports
      ..clear()
      ..addAll(originalReports);
  });

  for (final status in [QCReportStatus.DRAFT, QCReportStatus.SUBMITTED]) {
    test(
      '${status.name} bounds 32 uploads at three and preserves indexed order',
      () async {
        final api = _ConcurrentPersistenceApi();
        final provider = await _providerWithSamples(api);
        addTearDown(provider.dispose);
        final expectedPaths = _addPendingPhotos(provider);

        await provider.persistReport(status);

        expect(api.uploadCalls, hasLength(32));
        expect(api.maximumActiveUploads, 3);
        expect(api.maximumActiveUploads, greaterThanOrEqualTo(2));
        expect(api.postCalls, 1);
        expect(api.patchCalls, 0);
        expect(api.persistedReport!.status, status);
        expect(_persistedPaths(api.persistedReport!), expectedPaths);
        expect(
          api.uploadCalls.map((call) => call.bytes.toList()),
          List.generate(
            32,
            (photoNumber) => [
              photoNumber ~/ 8,
              (photoNumber % 8) ~/ 4,
              photoNumber % 4,
              photoNumber,
            ],
          ),
        );
        expect(
          _persistedPaths(api.persistedReport!)
              .expand((sample) => sample)
              .expand((item) => item)
              .every(
                (path) =>
                    path.startsWith('reports/${provider.reportId}/') &&
                    !path.startsWith('Z:/'),
              ),
          isTrue,
        );
      },
    );
  }

  test(
    'one sample submits eight retained photos without reprocessing',
    () async {
      final api = _ConcurrentPersistenceApi();
      final photoProcessor = _SubmitGuardPhotoProcessor();
      final provider = await _providerWithSamples(
        api,
        sampleCount: 1,
        photoProcessor: photoProcessor,
      );
      addTearDown(provider.dispose);
      final expectedPaths = _addPendingPhotos(provider);

      await provider.persistReport(QCReportStatus.SUBMITTED);

      expect(api.uploadCalls, hasLength(8));
      expect(api.maximumActiveUploads, 3);
      expect(photoProcessor.processCalls, 0);
      expect(api.postCalls, 1);
      expect(api.patchCalls, 0);
      expect(_persistedPaths(api.persistedReport!), expectedPaths);
    },
  );

  test('repeated submit while uploads are active sends one report', () async {
    final uploadGate = Completer<void>();
    final api = _ConcurrentPersistenceApi(uploadGate: uploadGate);
    final provider = await _providerWithSamples(api, sampleCount: 1);
    addTearDown(provider.dispose);
    _addPendingPhotos(provider);

    final firstSubmit = provider.persistReport(QCReportStatus.SUBMITTED);
    while (api.uploadCalls.length < 3) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(provider.isPersisting, isTrue);

    final repeatedSubmit = provider.persistReport(QCReportStatus.SUBMITTED);
    await repeatedSubmit;
    expect(api.uploadCalls, hasLength(3));
    expect(api.postCalls, 0);

    uploadGate.complete();
    await firstSubmit;

    expect(api.uploadCalls, hasLength(8));
    expect(api.maximumActiveUploads, 3);
    expect(api.postCalls, 1);
    expect(api.patchCalls, 0);
  });

  test(
    'canonical paths bypass upload and remain before pending paths',
    () async {
      final api = _ConcurrentPersistenceApi();
      final provider = await _providerWithSamples(api, sampleCount: 1);
      addTearDown(provider.dispose);
      const canonicalPath =
          'reports/QC-EXISTING/checklist/visual-item/'
          '10000000-0000-4000-8000-000000000000.jpg';
      provider.samples.single.answers[0].photoPaths.add(canonicalPath);
      final expectedLocalPaths = _addPendingPhotos(provider, photosPerItem: 1);

      await provider.persistReport(QCReportStatus.DRAFT);

      expect(api.uploadCalls, hasLength(2));
      expect(
        api.persistedReport!.samples.single.checklistAnswers[0].photoPaths,
        [canonicalPath, ...expectedLocalPaths.single[0]],
      );
      expect(
        api.uploadCalls.any((call) => call.fileName.contains('QC-EXISTING')),
        isFalse,
      );
    },
  );

  test(
    'partial failure withholds report and retry uploads only unfinished photos',
    () async {
      final api = _ConcurrentPersistenceApi(failOncePhotoNumbers: {1});
      final provider = await _providerWithSamples(api);
      addTearDown(provider.dispose);
      final expectedPaths = _addPendingPhotos(provider);

      await expectLater(
        provider.persistReport(QCReportStatus.DRAFT),
        throwsA(
          isA<QCMaterialPersistenceException>().having(
            (error) => error.message,
            'message',
            'Upload foto gagal untuk pengujian.',
          ),
        ),
      );

      expect(api.uploadCalls.map((call) => call.fileName), [
        _photoFileName(0),
        _photoFileName(1),
        _photoFileName(2),
      ]);
      expect(api.postCalls, 0);
      expect(api.patchCalls, 0);
      expect(provider.isPersisting, isFalse);
      expect(
        provider.samples
            .expand((sample) => sample.localItemPhotos)
            .expand((photos) => photos),
        hasLength(32),
      );

      await provider.persistReport(QCReportStatus.DRAFT);

      expect(api.uploadAttemptsByFileName[_photoFileName(0)], 1);
      expect(api.uploadAttemptsByFileName[_photoFileName(2)], 1);
      expect(api.uploadAttemptsByFileName[_photoFileName(1)], 2);
      for (var photoNumber = 3; photoNumber < 32; photoNumber++) {
        expect(api.uploadAttemptsByFileName[_photoFileName(photoNumber)], 1);
      }
      expect(api.postCalls, 1);
      expect(_persistedPaths(api.persistedReport!), expectedPaths);
      expect(
        provider.samples
            .expand((sample) => sample.localItemPhotos)
            .expand((photos) => photos),
        isEmpty,
      );
    },
  );

  test('single-photo and no-photo persistence remain valid', () async {
    final noPhotoApi = _ConcurrentPersistenceApi();
    final noPhotoProvider = await _providerWithSamples(
      noPhotoApi,
      sampleCount: 1,
    );
    addTearDown(noPhotoProvider.dispose);

    await noPhotoProvider.persistReport(QCReportStatus.DRAFT);

    expect(noPhotoApi.uploadCalls, isEmpty);
    expect(noPhotoApi.maximumActiveUploads, 0);
    expect(noPhotoApi.postCalls, 1);

    final singlePhotoApi = _ConcurrentPersistenceApi();
    final singlePhotoProvider = await _providerWithSamples(
      singlePhotoApi,
      sampleCount: 1,
    );
    addTearDown(singlePhotoProvider.dispose);
    final expectedPaths = _addPendingPhotos(
      singlePhotoProvider,
      photosPerItem: 0,
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final fileName = _photoFileName(0);
    singlePhotoProvider.samples.single.localItemPhotos[0].add(
      XFile(
        'Z:/missing-qc-evidence/$fileName',
        name: fileName,
        mimeType: 'image/jpeg',
        length: bytes.length,
      ),
    );
    singlePhotoProvider.samples.single.localItemPhotoBytes[0].add(bytes);
    expectedPaths.single[0].add(
      _objectPath(
        reportId: singlePhotoProvider.reportId,
        itemId: 'visual-item',
        photoNumber: 0,
      ),
    );

    await singlePhotoProvider.persistReport(QCReportStatus.SUBMITTED);

    expect(singlePhotoApi.uploadCalls, hasLength(1));
    expect(singlePhotoApi.uploadCalls.single.bytes, same(bytes));
    expect(singlePhotoApi.maximumActiveUploads, 1);
    expect(singlePhotoApi.postCalls, 1);
    expect(_persistedPaths(singlePhotoApi.persistedReport!), expectedPaths);
  });
}
