import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/dummy/dummy_state.dart';
import '../../core/dummy/dummy_sites.dart';
import '../../core/services/api_service.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/qc_report_model.dart'; // QCReportModel, AdminReview, StaffIdentity, ReportLocation
import '../../shared/models/qc_checklist_answer_model.dart';
import '../../shared/models/qc_material_template_model.dart';
import '../../shared/models/work_location_model.dart';
import '../../shared/models/site_model.dart';
import '../../shared/utils/qc_photo_validation.dart';
import '../../shared/services/qc_photo_processor.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/qc_validation_helper.dart';
import '../../shared/models/template_choice_option.dart';

enum QCMaterialPhotoAddResult { added, cancelled, fileTooLarge }

abstract class QCMaterialPersistenceApi {
  Future<QCEvidenceUploadResult> uploadQCEvidence({
    required XFile file,
    required String reportId,
    required String itemId,
  });

  Future<bool> postReport(QCReportModel report, {bool throwOnError = false});

  Future<bool> patchReport(QCReportModel report, {bool throwOnError = false});
}

class _DefaultQCMaterialPersistenceApi implements QCMaterialPersistenceApi {
  final ApiService _apiService = ApiService();

  @override
  Future<QCEvidenceUploadResult> uploadQCEvidence({
    required XFile file,
    required String reportId,
    required String itemId,
  }) => _apiService.uploadQCEvidence(
    file: file,
    reportId: reportId,
    itemId: itemId,
  );

  @override
  Future<bool> postReport(QCReportModel report, {bool throwOnError = false}) =>
      _apiService.postReport(report, throwOnError: throwOnError);

  @override
  Future<bool> patchReport(QCReportModel report, {bool throwOnError = false}) =>
      _apiService.patchReport(report, throwOnError: throwOnError);
}

class QCMaterialPersistenceException implements Exception {
  final String message;

  const QCMaterialPersistenceException(this.message);
}

class QCMaterialFormProvider extends ChangeNotifier {
  // Dependencies
  final DummyState _state = DummyState();
  final ImagePicker _imagePicker;
  final Future<XFile?> Function(ImageSource source)? photoPicker;
  final QCMaterialPersistenceApi _api;
  final QCPhotoProcessor _photoProcessor;
  final Map<XFile, String> _uploadedObjectPaths = {};
  final Set<int> _photoCapturesInProgress = <int>{};
  bool _isPersisting = false;
  bool _isDisposed = false;
  late String _reportId;

  QCMaterialFormProvider({
    ImagePicker? imagePicker,
    this.photoPicker,
    QCMaterialPersistenceApi? api,
    QCPhotoProcessor? photoProcessor,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _api = api ?? _DefaultQCMaterialPersistenceApi(),
       _photoProcessor = photoProcessor ?? BoundedQCPhotoProcessor();

  // Template
  late QCMaterialTemplate _template;
  bool _isInit = false;

  /// Public getters for UI consumption
  bool get isReady => _isInit;
  bool get isPersisting => _isPersisting;
  String get reportId => _reportId;
  QCMaterialTemplate get template => _template;

  // Controllers for general info
  final TextEditingController poNumberController = TextEditingController();
  final TextEditingController poDateController = TextEditingController();
  final TextEditingController doNumberController = TextEditingController();
  final TextEditingController vendorNameController = TextEditingController();
  final TextEditingController materialIdController = TextEditingController();
  final TextEditingController arrivalVolumeController = TextEditingController();
  final TextEditingController samplingVolumeController =
      TextEditingController();
  final TextEditingController brandNameController = TextEditingController();
  final TextEditingController warehouseLocationController =
      TextEditingController();
  final TextEditingController stelVersionController = TextEditingController();
  final TextEditingController qaExpiryDateController = TextEditingController();
  final TextEditingController tkdnNumberController = TextEditingController();
  final TextEditingController tkdnCertDateController = TextEditingController();
  final TextEditingController tkdnValueController = TextEditingController();
  final TextEditingController staffNoteController = TextEditingController();

  // Location
  SiteModel? selectedSite;
  bool isCustomLocation = false;
  final TextEditingController customLocNameController = TextEditingController();
  final TextEditingController customLocAreaController = TextEditingController();
  final TextEditingController customLocSegmentController =
      TextEditingController();
  final TextEditingController customLocNoteController = TextEditingController();

  void setSelectedSite(SiteModel site) {
    selectedSite = site;
    notifyListeners();
  }

  void setIsCustomLocation(bool val) {
    isCustomLocation = val;
    if (isCustomLocation) {
      selectedSite = null;
    } else {
      customLocNameController.clear();
      customLocAreaController.clear();
      customLocSegmentController.clear();
      customLocNoteController.clear();
    }
    notifyListeners();
  }

  String? validateLocation() {
    if (isCustomLocation) {
      if (customLocNameController.text.trim().isEmpty) {
        return 'Isi lokasi custom terlebih dahulu.';
      }
      return null;
    }
    if (selectedSite == null) {
      return 'Pilih lokasi kerja terlebih dahulu.';
    }
    return null;
  }

  // Checklist answers
  final List<QCChecklistAnswer> answers = [];
  final List<List<XFile>> localItemPhotos = [];
  final List<List<Uint8List>> localItemPhotoBytes = [];

  // Revision state
  bool isRevisionMode = false;
  String? editReportId;
  QCReportModel? _originalReport;

  void init(
    String materialId, {
    String? editReportId,
    bool isRevision = false,
    required QCMaterialTemplate template,
  }) {
    if (_isInit) return;
    // Use provided template if available (e.g., from API-loaded list).
    // Fall back to dummy templates only if no template was passed.
    _template = template;
    // Cache the resolved template so re-opening a draft can use the same template.
    _state.templateCache[_template.id] = _template;
    _reportId = editReportId ?? _newReportId();

    if (editReportId != null) {
      final report = _state.reports.firstWhere(
        (r) => r.id == editReportId,
        orElse: () => _state.reports[0],
      );
      _originalReport = report;
      this.editReportId = editReportId;
      isRevisionMode = isRevision;

      // Prefill fields
      poNumberController.text = report.generalInfo['poNumber'] ?? '';
      poDateController.text = report.generalInfo['poDate'] ?? '';
      doNumberController.text = report.generalInfo['doNumber'] ?? '';
      vendorNameController.text = report.generalInfo['vendorName'] ?? '';
      materialIdController.text =
          report.generalInfo['materialId'] ?? report.templateId;
      arrivalVolumeController.text = report.generalInfo['arrivalVolume'] ?? '';
      samplingVolumeController.text =
          report.generalInfo['samplingVolume'] ?? '';
      brandNameController.text = report.generalInfo['brandName'] ?? '';
      warehouseLocationController.text =
          report.generalInfo['warehouseLocation'] ?? '';
      stelVersionController.text = report.generalInfo['stelVersion'] ?? '';
      qaExpiryDateController.text = report.generalInfo['qaExpiryDate'] ?? '';
      tkdnNumberController.text = report.generalInfo['tkdnNumber'] ?? '';
      tkdnCertDateController.text = report.generalInfo['tkdnCertDate'] ?? '';
      tkdnValueController.text = report.generalInfo['tkdnValue'] ?? '';
      staffNoteController.text = report.staffNote;

      isCustomLocation = report.location.siteId == 'custom-site';
      if (isCustomLocation) {
        customLocNameController.text = report.location.siteName;
        customLocAreaController.text = report.location.area;
        customLocSegmentController.text = report.location.detailLocation;
      } else {
        if (report.location.siteId.isNotEmpty) {
          final matchingSites = dummySites.where(
            (s) => s.id == report.location.siteId,
          );
          selectedSite = matchingSites.isNotEmpty ? matchingSites.first : null;
        } else {
          selectedSite = null;
        }
      }

      // Populate checklist items
      answers.clear();
      for (var item in _template.checklistItems) {
        final matchingAnswer = report.checklistItems.firstWhere(
          (ans) => ans.itemId == item.id,
          orElse: () => QCChecklistAnswer(
            itemId: item.id,
            value: '',
            status: QCResultStatus.notFilled,
            photoPaths: [],
            paramName: item.label,
            standardText: item.standardText,
            unit: item.unit,
            inputType: item.inputType == QCInputType.number
                ? 'number'
                : item.inputType == QCInputType.choice
                ? 'choice'
                : 'text',
          ),
        );

        // Recalculate warning message / status locally
        final valRes = QCValidationHelper.validateChecklistAnswer(
          item: item,
          value: matchingAnswer.value?.toString() ?? '',
        );
        answers.add(
          matchingAnswer.copyWith(
            warningMessage: valRes.warningMessage,
            status: valRes.status,
          ),
        );
      }
    } else {
      // Prepopulate default template fields
      materialIdController.text = _template.id;
      stelVersionController.text = _template.code == 'TA-FR-048-010-01'
          ? 'STEL-L-017-2024 Ver.2'
          : 'STEL-QA-MYTA-2026';
      tkdnNumberController.text = 'TKDN-${_template.code}-2026';
      poDateController.text = '2026-07-01';
      qaExpiryDateController.text = '2028-12-31';
      tkdnCertDateController.text = '2026-01-15';
      selectedSite = _state.currentSite;

      // Initialize answers list
      for (var item in _template.checklistItems) {
        answers.add(
          QCChecklistAnswer(
            itemId: item.id,
            value: '',
            status: QCResultStatus.notFilled,
            photoPaths: [],
            paramName: item.label,
            standardText: item.standardText,
            unit: item.unit,
            inputType: item.inputType == QCInputType.number
                ? 'number'
                : item.inputType == QCInputType.choice
                ? 'choice'
                : 'text',
          ),
        );
      }
    }

    localItemPhotos
      ..clear()
      ..addAll(List.generate(answers.length, (_) => <XFile>[]));
    localItemPhotoBytes
      ..clear()
      ..addAll(List.generate(answers.length, (_) => <Uint8List>[]));

    _isInit = true;
    notifyListeners();
  }

  String _newReportId() {
    final random = Random.secure();
    final randomPart = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'QC-MAT-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  void updateAnswer(int index, String value) {
    final item = _template.checklistItems[index];
    final selectedOption = choiceOptionForValue(item.choiceOptions, value);
    if (item.inputType == QCInputType.choice &&
        selectedOption?.outcome == 'PASS') {
      answers[index].issueNote = '';
    }
    answers[index].value = value;
    final valRes = QCValidationHelper.validateChecklistAnswer(
      item: item,
      value: value,
    );
    answers[index].warningMessage = valRes.warningMessage;
    answers[index].status = valRes.status;
    notifyListeners();
  }

  Future<QCMaterialPhotoAddResult> addPhoto(int index) async {
    if (!_photoCapturesInProgress.add(index)) {
      return QCMaterialPhotoAddResult.cancelled;
    }
    try {
      final selectedPhoto =
          await (photoPicker?.call(ImageSource.camera) ??
              _imagePicker.pickImage(source: ImageSource.camera));
      if (selectedPhoto == null) return QCMaterialPhotoAddResult.cancelled;

      final QCProcessedPhoto processed;
      try {
        processed = await _photoProcessor.process(selectedPhoto);
      } on QCPhotoProcessingException {
        return QCMaterialPhotoAddResult.fileTooLarge;
      }
      if (_isDisposed) {
        if (processed.isGenerated) {
          await _photoProcessor.deleteGeneratedFile(processed.file);
        }
        return QCMaterialPhotoAddResult.cancelled;
      }
      if (exceedsQCPhotoSizeLimit(processed.bytes)) {
        if (processed.isGenerated) {
          await _photoProcessor.deleteGeneratedFile(processed.file);
        }
        return QCMaterialPhotoAddResult.fileTooLarge;
      }
      localItemPhotos[index].add(processed.file);
      localItemPhotoBytes[index].add(processed.bytes);
      notifyListeners();
      return QCMaterialPhotoAddResult.added;
    } finally {
      _photoCapturesInProgress.remove(index);
    }
  }

  void removePhoto(int index, int photoIdx) {
    final itemId = _template.checklistItems[index].id;
    final answerIndex = answers.indexWhere((answer) => answer.itemId == itemId);
    final answer = answers[answerIndex];
    final storedPhotoCount = answer.photoPaths.length;
    if (photoIdx < storedPhotoCount) {
      final updatedPhotoPaths = List<String>.from(answer.photoPaths)
        ..removeAt(photoIdx);
      answers[answerIndex] = answer.copyWith(photoPaths: updatedPhotoPaths);
    } else {
      final localIndex = photoIdx - storedPhotoCount;
      final removed = localItemPhotos[index].removeAt(localIndex);
      localItemPhotoBytes[index].removeAt(localIndex);
      _uploadedObjectPaths.remove(removed);
      unawaited(_photoProcessor.deleteGeneratedFile(removed));
    }
    notifyListeners();
  }

  void updateIssueNote(int index, String value) {
    answers[index].issueNote = value;
    notifyListeners();
  }

  bool get hasAnyDraftContent {
    return poNumberController.text.trim().isNotEmpty ||
        doNumberController.text.trim().isNotEmpty ||
        vendorNameController.text.trim().isNotEmpty ||
        staffNoteController.text.trim().isNotEmpty ||
        answers.any((a) => a.value.toString().trim().isNotEmpty) ||
        answers.any((a) => a.photoPaths.isNotEmpty) ||
        localItemPhotos.any((photos) => photos.isNotEmpty);
  }

  String? validateForm() {
    for (int i = 0; i < _template.checklistItems.length; i++) {
      final item = _template.checklistItems[i];
      final valStr = answers[i].value.toString().trim();
      final issue = answers[i].issueNote?.trim() ?? '';
      final photos = answers[i].photoPaths;

      if (item.required && valStr.isEmpty) {
        if (item.inputType == QCInputType.number) {
          return 'Form ${i + 1} - ${item.label}: isi nilai pengujian terlebih dahulu';
        } else if (item.inputType == QCInputType.choice) {
          return 'Form ${i + 1} - ${item.label}: pilih kesesuaian fisik terlebih dahulu';
        } else {
          return 'Form ${i + 1} - ${item.label}: isi hasil input terlebih dahulu';
        }
      }

      if (item.inputType == QCInputType.number) {
        if (!QCValidators.isValidNumber(valStr)) {
          return 'Form ${i + 1} - ${item.label}: masukkan angka yang valid';
        }
        final valNum = double.tryParse(valStr.replaceAll(',', '.'));
        if (valNum != null && valNum < 0) {
          return 'Form ${i + 1} - ${item.label}: nilai tidak boleh negatif';
        }
      }

      if (item.requiredPhoto && photos.isEmpty && localItemPhotos[i].isEmpty) {
        return 'Form ${i + 1} - ${item.label}: tambahkan dokumentasi foto terlebih dahulu';
      }

      final isNonIdeal =
          item.inputType == QCInputType.choice &&
          choiceOptionForValue(item.choiceOptions, valStr)?.outcome == 'FAIL';
      if (isNonIdeal && issue.isEmpty) {
        return 'Form ${i + 1} - ${item.label}: isi keterangan masalah terlebih dahulu';
      }
    }
    return null;
  }

  List<QCChecklistAnswer> _snapshotAnswersByItemId(
    List<List<String>> persistedPhotos,
  ) {
    final answersByItemId = {
      for (final answer in answers) answer.itemId: answer,
    };
    final photosByItemId = <String, List<String>>{};
    for (var i = 0; i < _template.checklistItems.length; i++) {
      photosByItemId[_template.checklistItems[i].id] = persistedPhotos[i];
    }
    return _template.checklistItems
        .map((item) {
          final answer = answersByItemId[item.id];
          if (answer != null) {
            return answer.copyWith(
              status: QCResultStatus.notFilled,
              photoPaths: List<String>.unmodifiable(
                photosByItemId[item.id] ?? const <String>[],
              ),
            );
          }
          return QCChecklistAnswer(
            itemId: item.id,
            value: '',
            status: QCResultStatus.notFilled,
            photoPaths: [],
            paramName: item.label,
            standardText: item.standardText,
            unit: item.unit,
            inputType: item.inputType == QCInputType.number
                ? 'number'
                : item.inputType == QCInputType.choice
                ? 'choice'
                : item.inputType == QCInputType.booleanCheck
                ? 'boolean'
                : 'text',
          );
        })
        .toList(growable: false);
  }

  Future<void> persistReport(QCReportStatus status) async {
    if (_isPersisting) return;
    _isPersisting = true;
    notifyListeners();

    try {
      final persistedPhotos = await _uploadPendingPhotos();
      await _persistReport(status, persistedPhotos);
      _commitPersistedPhotos(persistedPhotos);
    } on QCMaterialPersistenceException {
      rethrow;
    } on ApiRequestException catch (error) {
      throw QCMaterialPersistenceException(error.message);
    } catch (_) {
      throw const QCMaterialPersistenceException(
        'Foto atau laporan gagal disimpan. Silakan coba lagi.',
      );
    } finally {
      _isPersisting = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> _persistReport(
    QCReportStatus status,
    List<List<String>> persistedPhotos,
  ) async {
    final workLoc = WorkLocation(
      siteName: isCustomLocation
          ? customLocNameController.text
          : (selectedSite?.name ?? ''),
      area: isCustomLocation
          ? customLocAreaController.text
          : (selectedSite != null ? 'Area Site Utama' : ''),
      segment: isCustomLocation
          ? customLocSegmentController.text
          : (selectedSite != null ? 'Segmen Default' : ''),
      note: isCustomLocation ? customLocNoteController.text : '',
      isCustom: isCustomLocation,
    );
    final Map<String, String> genInfo = {
      'poNumber': poNumberController.text.trim(),
      'poDate': poDateController.text.trim(),
      'doNumber': doNumberController.text.trim(),
      'vendorName': vendorNameController.text.trim(),
      'materialId': materialIdController.text.trim(),
      'arrivalVolume': arrivalVolumeController.text.trim(),
      'samplingVolume': samplingVolumeController.text.trim(),
      'brandName': brandNameController.text.trim(),
      'warehouseLocation': warehouseLocationController.text.trim(),
      'stelVersion': stelVersionController.text.trim(),
      'qaExpiryDate': qaExpiryDateController.text.trim(),
      'tkdnNumber': tkdnNumberController.text.trim(),
      'tkdnCertDate': tkdnCertDateController.text.trim(),
      'tkdnValue': tkdnValueController.text.trim(),
    };
    final answerSnapshot = _snapshotAnswersByItemId(persistedPhotos);

    if (_originalReport != null) {
      final updatedHistory = List<QCReportModel>.from(
        _originalReport!.revisionHistory,
      );
      if (isRevisionMode) updatedHistory.add(_originalReport!);

      final updatedReport = QCReportModel(
        id: _reportId,
        title: _originalReport!.title,
        type: _originalReport!.type,
        status: isRevisionMode ? QCReportStatus.SUBMITTED : status,
        checkedByName: _state.currentUser.name,
        checkedByNik: _state.currentUser.nik,
        date: DateTime.now(), // submittedAt updated on resubmit
        siteId: isCustomLocation ? 'custom-site' : (selectedSite?.id ?? ''),
        siteName: workLoc.siteName,
        area: workLoc.area ?? '',
        detailLocation: workLoc.segment ?? '',
        checklistAnswers: answerSnapshot,
        photos: [],
        staffNote: staffNoteController.text,
        adminNote: isRevisionMode ? null : _originalReport!.adminNote,
        adminReview: isRevisionMode
            ? AdminReview()
            : _originalReport!.adminReview,
        formCode: _originalReport!.formCode,
        templateId: _originalReport!.templateId,
        generalInfo: genInfo,
        revisionNumber:
            _originalReport!.revisionNumber + (isRevisionMode ? 1 : 0),
        revisionHistory: updatedHistory,
      );
      final saved = await _api.patchReport(updatedReport, throwOnError: true);
      if (!saved) {
        throw const QCMaterialPersistenceException(
          'Laporan gagal disimpan. Periksa koneksi lalu coba lagi.',
        );
      }
      _state.updateReportLocally(updatedReport);
    } else {
      final newReport = QCReportModel(
        id: _reportId,
        title: _template.name,
        type: QCType.material,
        status: status,
        checkedByName: _state.currentUser.name,
        checkedByNik: _state.currentUser.nik,
        date: DateTime.now(),
        siteId: isCustomLocation ? 'custom-site' : (selectedSite?.id ?? ''),
        siteName: workLoc.siteName,
        area: workLoc.area ?? '',
        detailLocation: workLoc.segment ?? '',
        checklistAnswers: answerSnapshot,
        photos: [],
        staffNote: staffNoteController.text,
        adminNote: status == QCReportStatus.DRAFT
            ? null
            : 'Menunggu review dari Admin.',
        formCode: _template.code,
        templateId: _template.id,
        generalInfo: genInfo,
        finalConclusion: status == QCReportStatus.DRAFT
            ? 'Belum Lengkap'
            : 'Pending',
        revisionNumber: 1,
        revisionHistory: [],
      );
      final saved = await _api.postReport(newReport, throwOnError: true);
      if (!saved) {
        throw const QCMaterialPersistenceException(
          'Laporan gagal disimpan. Periksa koneksi lalu coba lagi.',
        );
      }
      _state.addReportLocally(newReport);
    }
  }

  Future<List<List<String>>> _uploadPendingPhotos() async {
    final answersByItemId = {
      for (final answer in answers) answer.itemId: answer,
    };
    final persistedPhotos = _template.checklistItems
        .map(
          (item) => List<String>.from(
            answersByItemId[item.id]?.photoPaths ?? const <String>[],
          ),
        )
        .toList(growable: false);

    for (var i = 0; i < persistedPhotos.length; i++) {
      final photos = persistedPhotos[i];
      if (photos.any(
        (photo) => !_isCanonicalObjectPath(photo) && !_isHttpUrl(photo),
      )) {
        throw const QCMaterialPersistenceException(
          'Laporan memiliki referensi foto yang tidak valid.',
        );
      }
      persistedPhotos[i] = photos.where(_isCanonicalObjectPath).toList();
    }

    for (var itemIndex = 0; itemIndex < localItemPhotos.length; itemIndex++) {
      final itemId = _template.checklistItems[itemIndex].id;
      for (final photo in localItemPhotos[itemIndex]) {
        var objectPath = _uploadedObjectPaths[photo];
        if (objectPath == null) {
          final bytes = await photo.readAsBytes();
          if (exceedsQCPhotoSizeLimit(bytes)) {
            throw const QCMaterialPersistenceException(qcPhotoTooLargeMessage);
          }
          final uploaded = await _api.uploadQCEvidence(
            file: photo,
            reportId: _reportId,
            itemId: itemId,
          );
          objectPath = uploaded.objectPath;
          if (!_isCanonicalObjectPath(objectPath)) {
            throw const QCMaterialPersistenceException(
              'Server mengembalikan referensi foto yang tidak valid.',
            );
          }
          _uploadedObjectPaths[photo] = objectPath;
        }
        persistedPhotos[itemIndex].add(objectPath);
      }
    }
    return persistedPhotos;
  }

  void _commitPersistedPhotos(List<List<String>> persistedPhotos) {
    final photosByItemId = <String, List<String>>{};
    for (var i = 0; i < _template.checklistItems.length; i++) {
      photosByItemId[_template.checklistItems[i].id] = persistedPhotos[i];
      for (final photo in localItemPhotos[i]) {
        unawaited(_photoProcessor.deleteGeneratedFile(photo));
      }
      localItemPhotos[i].clear();
      localItemPhotoBytes[i].clear();
    }
    for (var i = 0; i < answers.length; i++) {
      final answer = answers[i];
      answers[i] = answer.copyWith(
        photoPaths: List<String>.from(
          photosByItemId[answer.itemId] ?? const <String>[],
        ),
      );
    }
    _uploadedObjectPaths.clear();
  }

  bool _isCanonicalObjectPath(String value) => RegExp(
    r'^reports/[A-Za-z0-9_-]{1,128}/(?:general/[0-9a-f-]{36}|checklist/[A-Za-z0-9_-]{1,128}/[0-9a-f-]{36})\.(?:jpg|png|webp|heic)$',
  ).hasMatch(value);

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final photos in localItemPhotos) {
      for (final photo in photos) {
        unawaited(_photoProcessor.deleteGeneratedFile(photo));
      }
    }
    _isPersisting = false;
    poNumberController.dispose();
    poDateController.dispose();
    doNumberController.dispose();
    vendorNameController.dispose();
    materialIdController.dispose();
    arrivalVolumeController.dispose();
    samplingVolumeController.dispose();
    brandNameController.dispose();
    warehouseLocationController.dispose();
    stelVersionController.dispose();
    qaExpiryDateController.dispose();
    tkdnNumberController.dispose();
    tkdnCertDateController.dispose();
    tkdnValueController.dispose();
    staffNoteController.dispose();
    customLocNameController.dispose();
    customLocAreaController.dispose();
    customLocSegmentController.dispose();
    customLocNoteController.dispose();
    super.dispose();
  }
}
