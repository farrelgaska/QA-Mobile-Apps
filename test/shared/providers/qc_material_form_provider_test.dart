import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/models/qc_report_model.dart';
import 'package:mobile/shared/models/template_choice_option.dart';
import 'package:mobile/shared/providers/qc_material_form_provider.dart';

class _UploadCall {
  final XFile file;
  final String reportId;
  final String itemId;

  const _UploadCall(this.file, this.reportId, this.itemId);
}

class _FakeMaterialPersistenceApi implements QCMaterialPersistenceApi {
  final bool failUpload;
  final bool failFirstReportPersistence;
  final List<_UploadCall> uploads = [];
  final List<QCReportModel> reportAttempts = [];
  int reportPersistenceAttempts = 0;
  QCReportModel? postedReport;
  QCReportModel? patchedReport;

  _FakeMaterialPersistenceApi({
    this.failUpload = false,
    this.failFirstReportPersistence = false,
  });

  @override
  Future<QCEvidenceUploadResult> uploadQCEvidence({
    required XFile file,
    required String reportId,
    required String itemId,
  }) async {
    uploads.add(_UploadCall(file, reportId, itemId));
    if (failUpload) {
      throw const ApiRequestException('Upload foto gagal untuk pengujian.');
    }
    return QCEvidenceUploadResult(
      objectPath:
          'reports/$reportId/checklist/$itemId/362a1d19-23cf-4950-9671-41e1293d68f2.png',
      mimeType: 'image/png',
      size: await file.length(),
    );
  }

  @override
  Future<bool> patchReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    reportPersistenceAttempts++;
    final snapshot = QCReportModel.fromJson(report.toJson());
    reportAttempts.add(snapshot);
    if (failFirstReportPersistence && reportPersistenceAttempts == 1) {
      return false;
    }
    patchedReport = snapshot;
    return true;
  }

  @override
  Future<bool> postReport(
    QCReportModel report, {
    bool throwOnError = false,
  }) async {
    reportPersistenceAttempts++;
    final snapshot = QCReportModel.fromJson(report.toJson());
    reportAttempts.add(snapshot);
    if (failFirstReportPersistence && reportPersistenceAttempts == 1) {
      return false;
    }
    postedReport = snapshot;
    return true;
  }
}

QCMaterialTemplate _draftTemplate() => QCMaterialTemplate(
  id: 'MAT-DRAFT-SNAPSHOT',
  name: 'Material draft snapshot',
  code: 'MAT-DRAFT',
  description: '',
  checklistItems: [
    QCChecklistItem(
      id: 'number-1',
      label: 'Diameter luar',
      category: 'Dimensi',
      inputType: QCInputType.number,
      standardText: '100 mm',
      unit: 'mm',
    ),
    QCChecklistItem(
      id: 'boolean-1',
      label: 'Terdapat tanda tanam',
      category: 'Fisik',
      inputType: QCInputType.booleanCheck,
      standardText: 'Ada',
    ),
    QCChecklistItem(
      id: 'choice-1',
      label: 'Warna cat',
      category: 'Fisik',
      inputType: QCInputType.choice,
      standardText: 'Sesuai',
      choiceOptions: const [
        TemplateChoiceOption(
          id: 'pass',
          label: 'Sesuai',
          value: 'Sesuai',
          outcome: 'PASS',
          position: 0,
        ),
        TemplateChoiceOption(
          id: 'fail',
          label: 'Tidak Sesuai',
          value: 'Tidak Sesuai',
          outcome: 'FAIL',
          position: 1,
        ),
      ],
    ),
    QCChecklistItem(
      id: 'text-1',
      label: 'Keterangan',
      category: 'Teks',
      inputType: QCInputType.text,
      standardText: 'Catatan',
    ),
  ],
);

XFile _localPng() => XFile.fromData(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
  name: 'qc-material.png',
  mimeType: 'image/png',
);

void main() {
  test('material choice validation and stale note follow option outcome', () {
    final template = QCMaterialTemplate(
      id: 'MAT-CHOICE',
      name: 'Material choice',
      code: 'MAT-01',
      description: '',
      checklistItems: [
        QCChecklistItem(
          id: 'choice',
          label: 'Kondisi',
          category: 'Visual',
          inputType: QCInputType.choice,
          standardText: 'Harus rapi',
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
    );
    final provider = QCMaterialFormProvider()
      ..init(template.id, template: template);
    addTearDown(provider.dispose);

    provider.updateAnswer(0, 'CUSTOM_FAIL');
    expect(provider.validateForm(), contains('keterangan masalah'));

    provider.updateIssueNote(0, 'Kondisi berantakan');
    expect(provider.validateForm(), isNull);

    provider.updateAnswer(0, 'CUSTOM_PASS');
    expect(provider.answers.single.issueNote, isEmpty);
    expect(provider.validateForm(), isNull);
  });

  test(
    'draft uploads local photo and snapshots multiple answer types by item ID',
    () async {
      const existingPhotoPath =
          'reports/QC-MAT-EXISTING/checklist/number-1/462a1d19-23cf-4950-9671-41e1293d68f2.jpg';
      final template = _draftTemplate();
      final api = _FakeMaterialPersistenceApi();
      final localPhoto = _localPng();
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      final provider = QCMaterialFormProvider(api: api)
        ..init(template.id, template: template);
      final freshProvider = QCMaterialFormProvider(api: api);

      addTearDown(() {
        provider.dispose();
        freshProvider.dispose();
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      provider.updateAnswer(0, '12333');
      provider.updateAnswer(1, 'Ya');
      provider.updateAnswer(2, 'Sesuai');
      provider.updateAnswer(3, 'Semua permukaan baik');
      provider.updateIssueNote(1, 'Tanda terlihat jelas');
      provider.answers[0].photoPaths.add(existingPhotoPath);
      provider.answers.setAll(0, provider.answers.reversed.toList());
      provider.localItemPhotos[1].add(localPhoto);
      provider.localItemPhotoBytes[1].add(await localPhoto.readAsBytes());

      await provider.persistReport(QCReportStatus.DRAFT);

      final saved = state.reports.firstWhere(
        (report) => report.id == provider.reportId,
      );
      final savedById = {
        for (final answer in saved.checklistItems) answer.itemId: answer,
      };
      final uploadedPath = api.uploads.single;
      final expectedUploadedPath =
          'reports/${provider.reportId}/checklist/boolean-1/362a1d19-23cf-4950-9671-41e1293d68f2.png';
      final restored = QCReportModel.fromJson(saved.toJson());
      final restoredById = {
        for (final answer in restored.checklistItems) answer.itemId: answer,
      };

      freshProvider.init(
        template.id,
        editReportId: saved.id,
        template: template,
      );
      final freshById = {
        for (final answer in freshProvider.answers) answer.itemId: answer,
      };

      expect(uploadedPath.file.mimeType, 'image/png');
      expect(uploadedPath.reportId, provider.reportId);
      expect(uploadedPath.itemId, 'boolean-1');
      expect(api.postedReport?.id, provider.reportId);
      expect(savedById['boolean-1']!.photoPaths, [expectedUploadedPath]);
      expect(freshProvider.reportId, saved.id);
      expect(restored.checklistItems.map((answer) => answer.itemId), [
        'number-1',
        'boolean-1',
        'choice-1',
        'text-1',
      ]);
      expect(restoredById['number-1']!.value, '12333');
      expect(restoredById['boolean-1']!.value, 'Ya');
      expect(restoredById['choice-1']!.value, 'Sesuai');
      expect(restoredById['text-1']!.value, 'Semua permukaan baik');
      expect(restoredById['boolean-1']!.issueNote, 'Tanda terlihat jelas');
      expect(restoredById['number-1']!.photoPaths, [existingPhotoPath]);
      expect(restoredById['boolean-1']!.photoPaths, [expectedUploadedPath]);
      expect(freshById['boolean-1']!.photoPaths, [expectedUploadedPath]);
      expect(provider.localItemPhotos[1], isEmpty);
      expect(provider.localItemPhotoBytes[1], isEmpty);
      expect(
        restored.checklistItems.every(
          (answer) => answer.status == QCResultStatus.notFilled,
        ),
        isTrue,
      );
    },
  );

  test(
    'edited draft persists only canonical photo paths in original order',
    () async {
      const canonicalFirst =
          'reports/QC-MAT-URL-FILTER/checklist/number-1/162a1d19-23cf-4950-9671-41e1293d68f2.jpg';
      const canonicalSecond =
          'reports/QC-MAT-URL-FILTER/checklist/number-1/262a1d19-23cf-4950-9671-41e1293d68f2.png';
      const canonicalThird =
          'reports/QC-MAT-URL-FILTER/checklist/number-1/362a1d19-23cf-4950-9671-41e1293d68f2.webp';
      const httpsUrl = 'https://example.com/photos/material.jpg';
      const httpUrl = 'http://example.com/photos/material.png';
      const signedUrl =
          'https://project.supabase.co/storage/v1/object/sign/qc-evidence/reports/material.jpg?token=signed-token';
      final template = _draftTemplate();
      final api = _FakeMaterialPersistenceApi();
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      final initialProvider = QCMaterialFormProvider(api: api)
        ..init(template.id, template: template);
      final restoredProvider = QCMaterialFormProvider(api: api);
      final freshProvider = QCMaterialFormProvider(api: api);

      addTearDown(() {
        initialProvider.dispose();
        restoredProvider.dispose();
        freshProvider.dispose();
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      initialProvider.answers[0].photoPaths.add(canonicalFirst);
      await initialProvider.persistReport(QCReportStatus.DRAFT);
      final saved = state.reports.firstWhere(
        (report) => report.id == initialProvider.reportId,
      );
      saved.checklistItems
          .firstWhere((answer) => answer.itemId == 'number-1')
          .photoPaths = List<String>.unmodifiable([
        canonicalFirst,
        httpsUrl,
        canonicalSecond,
        httpUrl,
        signedUrl,
        canonicalThird,
      ]);

      restoredProvider.init(
        template.id,
        editReportId: saved.id,
        template: template,
      );
      await restoredProvider.persistReport(QCReportStatus.DRAFT);

      final expectedPaths = [
        canonicalFirst,
        canonicalSecond,
        canonicalThird,
      ];
      final outgoingRoundTrip = QCReportModel.fromJson(
        api.patchedReport!.toJson(),
      );
      final outgoingPaths = outgoingRoundTrip.checklistItems
          .firstWhere((answer) => answer.itemId == 'number-1')
          .photoPaths;
      expect(outgoingPaths, expectedPaths);
      expect(outgoingPaths, isNot(contains(httpsUrl)));
      expect(outgoingPaths, isNot(contains(httpUrl)));
      expect(outgoingPaths, isNot(contains(signedUrl)));
      expect(api.uploads, isEmpty);

      final updated = state.reports.firstWhere(
        (report) => report.id == saved.id,
      );
      freshProvider.init(
        template.id,
        editReportId: updated.id,
        template: template,
      );
      final reopenedPaths = freshProvider.answers
          .firstWhere((answer) => answer.itemId == 'number-1')
          .photoPaths;
      expect(reopenedPaths, expectedPaths);
      expect(reopenedPaths, isNot(contains(httpsUrl)));
      expect(reopenedPaths, isNot(contains(httpUrl)));
      expect(reopenedPaths, isNot(contains(signedUrl)));
    },
  );

  test(
    'removing a restored canonical photo survives edited draft round-trip',
    () async {
      const firstPhoto =
          'reports/QC-MAT-RESTORED/checklist/number-1/162a1d19-23cf-4950-9671-41e1293d68f2.jpg';
      const secondPhoto =
          'reports/QC-MAT-RESTORED/checklist/number-1/262a1d19-23cf-4950-9671-41e1293d68f2.jpg';
      const otherItemPhoto =
          'reports/QC-MAT-RESTORED/checklist/boolean-1/362a1d19-23cf-4950-9671-41e1293d68f2.jpg';
      final template = _draftTemplate();
      final api = _FakeMaterialPersistenceApi();
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      final initialProvider = QCMaterialFormProvider(api: api)
        ..init(template.id, template: template);
      final restoredProvider = QCMaterialFormProvider(api: api);
      final freshProvider = QCMaterialFormProvider(api: api);

      addTearDown(() {
        initialProvider.dispose();
        restoredProvider.dispose();
        freshProvider.dispose();
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      initialProvider.answers[0].photoPaths.addAll([firstPhoto, secondPhoto]);
      initialProvider.answers[1].photoPaths.add(otherItemPhoto);
      await initialProvider.persistReport(QCReportStatus.DRAFT);

      final saved = state.reports.firstWhere(
        (report) => report.id == initialProvider.reportId,
      );
      restoredProvider.init(
        template.id,
        editReportId: saved.id,
        template: template,
      );
      final restoredById = {
        for (final answer in restoredProvider.answers) answer.itemId: answer,
      };
      expect(
        () => restoredById['number-1']!.photoPaths.removeAt(0),
        throwsUnsupportedError,
      );

      restoredProvider.answers.setAll(
        0,
        restoredProvider.answers.reversed.toList(),
      );
      expect(() => restoredProvider.removePhoto(0, 0), returnsNormally);
      final afterDeleteById = {
        for (final answer in restoredProvider.answers) answer.itemId: answer,
      };
      expect(afterDeleteById['number-1']!.photoPaths, [secondPhoto]);
      expect(afterDeleteById['boolean-1']!.photoPaths, [otherItemPhoto]);

      await restoredProvider.persistReport(QCReportStatus.DRAFT);
      expect(api.patchedReport?.id, saved.id);
      expect(api.uploads, isEmpty);

      final updated = state.reports.firstWhere(
        (report) => report.id == saved.id,
      );
      freshProvider.init(
        template.id,
        editReportId: updated.id,
        template: template,
      );
      final freshById = {
        for (final answer in freshProvider.answers) answer.itemId: answer,
      };
      expect(freshById['number-1']!.photoPaths, [secondPhoto]);
      expect(freshById['boolean-1']!.photoPaths, [otherItemPhoto]);
    },
  );

  test(
    'upload failure keeps pending photo and does not create draft',
    () async {
      final template = _draftTemplate();
      final api = _FakeMaterialPersistenceApi(failUpload: true);
      final localPhoto = _localPng();
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      final provider = QCMaterialFormProvider(api: api)
        ..init(template.id, template: template);

      addTearDown(() {
        provider.dispose();
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      provider.updateAnswer(1, 'Ya');
      provider.localItemPhotos[1].add(localPhoto);
      provider.localItemPhotoBytes[1].add(await localPhoto.readAsBytes());

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

      expect(api.uploads.single.reportId, provider.reportId);
      expect(api.uploads.single.itemId, 'boolean-1');
      expect(api.postedReport, isNull);
      expect(
        state.reports.any((report) => report.id == provider.reportId),
        false,
      );
      expect(provider.localItemPhotos[1], [same(localPhoto)]);
      expect(provider.localItemPhotoBytes[1], isNotEmpty);
      expect(provider.answers[1].photoPaths, isEmpty);
      expect(provider.isPersisting, isFalse);
    },
  );

  test(
    'report failure retries without reuploading the pending photo',
    () async {
      final template = _draftTemplate();
      final api = _FakeMaterialPersistenceApi(
        failFirstReportPersistence: true,
      );
      final localPhoto = _localPng();
      final previewBytes = await localPhoto.readAsBytes();
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      final provider = QCMaterialFormProvider(api: api)
        ..init(template.id, template: template);

      addTearDown(() {
        provider.dispose();
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      provider.updateAnswer(1, 'Ya');
      provider.localItemPhotos[1].add(localPhoto);
      provider.localItemPhotoBytes[1].add(previewBytes);

      await expectLater(
        provider.persistReport(QCReportStatus.DRAFT),
        throwsA(
          isA<QCMaterialPersistenceException>().having(
            (error) => error.message,
            'message',
            'Laporan gagal disimpan. Periksa koneksi lalu coba lagi.',
          ),
        ),
      );

      final expectedObjectPath =
          'reports/${provider.reportId}/checklist/boolean-1/362a1d19-23cf-4950-9671-41e1293d68f2.png';
      final firstAttemptPaths = api.reportAttempts.single.checklistItems
          .firstWhere((answer) => answer.itemId == 'boolean-1')
          .photoPaths;
      expect(api.uploads, hasLength(1));
      expect(api.reportPersistenceAttempts, 1);
      expect(
        state.reports.any((report) => report.id == provider.reportId),
        false,
      );
      expect(provider.isPersisting, isFalse);
      expect(provider.localItemPhotos[1], [same(localPhoto)]);
      expect(provider.localItemPhotoBytes[1], [previewBytes]);
      expect(provider.answers[1].photoPaths, isEmpty);
      expect(firstAttemptPaths, [expectedObjectPath]);

      await provider.persistReport(QCReportStatus.DRAFT);

      final saved = state.reports.firstWhere(
        (report) => report.id == provider.reportId,
      );
      final savedPaths = saved.checklistItems
          .firstWhere((answer) => answer.itemId == 'boolean-1')
          .photoPaths;
      final secondAttemptPaths = api.reportAttempts.last.checklistItems
          .firstWhere((answer) => answer.itemId == 'boolean-1')
          .photoPaths;
      expect(api.uploads, hasLength(1));
      expect(api.uploads.single.reportId, provider.reportId);
      expect(api.uploads.single.itemId, 'boolean-1');
      expect(api.reportPersistenceAttempts, 2);
      expect(api.reportAttempts.map((report) => report.id), [
        provider.reportId,
        provider.reportId,
      ]);
      expect(secondAttemptPaths, [expectedObjectPath]);
      expect(savedPaths, [expectedObjectPath]);
      expect(
        savedPaths.where((path) => path == expectedObjectPath),
        hasLength(1),
      );
      expect(provider.localItemPhotos[1], isEmpty);
      expect(provider.localItemPhotoBytes[1], isEmpty);
    },
  );
}
