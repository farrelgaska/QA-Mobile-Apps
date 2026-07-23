import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/dummy/dummy_state.dart';
import '../../core/services/api_service.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/qc_report_model.dart'; // QCReportModel, AdminReview
import '../../shared/models/qc_checklist_answer_model.dart';
import '../../shared/models/qc_photo_processing_entry.dart';
import '../../shared/models/work_location_model.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/pekerjaan_model.dart';
import '../../shared/models/template_choice_option.dart';
import '../../shared/utils/qc_photo_validation.dart';
import '../../shared/services/qc_photo_processor.dart';

enum PhotoAddResult { added, cancelled, limitReached, fileTooLarge }

class ReportPersistenceException implements Exception {
  final String message;

  const ReportPersistenceException(this.message);
}

class QCPekerjaanFormProvider extends ChangeNotifier {
  static const int maxPhotosPerItem = 5;

  final DummyState _state = DummyState();
  final ImagePicker _imagePicker;
  final Future<XFile?> Function(ImageSource source)? photoPicker;
  final ApiService _apiService;
  final QCPhotoProcessor _photoProcessor;
  final Set<int> _photoCapturesInProgress = <int>{};
  int _processingPhotoSequence = 0;
  bool _isInit = false;
  bool _submitAttempted = false;
  bool _isPersisting = false;
  bool _isDisposed = false;
  late String _reportId;
  late PekerjaanModel _pekerjaan;

  QCPekerjaanFormProvider({
    ImagePicker? imagePicker,
    this.photoPicker,
    ApiService? apiService,
    QCPhotoProcessor? photoProcessor,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _apiService = apiService ?? ApiService(),
       _photoProcessor = photoProcessor ?? BoundedQCPhotoProcessor();

  /// Public getters for UI consumption
  bool get isReady => _isInit;
  bool get submitAttempted => _submitAttempted;
  bool get isPersisting => _isPersisting;
  bool get hasProcessingPhotos =>
      processingItemPhotos.any((photos) => photos.isNotEmpty);
  PekerjaanModel get pekerjaan => _pekerjaan;
  DummyState get state => _state;

  // General controllers
  final TextEditingController areaController = TextEditingController();
  final TextEditingController locationDetailController =
      TextEditingController();
  final TextEditingController mitraController = TextEditingController();
  final TextEditingController staffNoteController = TextEditingController();

  // Checklist state
  final List<ChecklistStatus> itemStatuses = [];
  final List<String> itemResults = [];
  final List<String> itemIssues = [];
  final List<List<String>> itemPhotos = [];
  final List<List<XFile>> pendingItemPhotos = [];
  final List<List<Uint8List>> pendingItemPhotoBytes = [];
  final List<List<QCPhotoProcessingEntry>> processingItemPhotos = [];
  final Map<String, Uint8List> uploadedPhotoPreviewBytes = {};
  final List<String?> itemWarnings = [];
  final List<String?> itemAdminNotes = [];
  final Map<XFile, String> _uploadedObjectPaths = {};

  // Revision state
  bool isRevisionMode = false;
  String? editReportId;
  QCReportModel? _originalReport;

  void init(
    PekerjaanModel pekerjaan, {
    String? editReportId,
    bool isRevision = false,
  }) {
    if (_isInit) return;
    _pekerjaan = pekerjaan;
    _state.workTemplateCache[pekerjaan.id] = pekerjaan;
    _reportId = editReportId ?? _newReportId();

    if (editReportId != null) {
      final reportIndex = _state.reports.indexWhere(
        (r) => r.id == editReportId,
      );
      if (reportIndex == -1) {
        throw StateError('Laporan $editReportId tidak ditemukan.');
      }
      final report = _state.reports[reportIndex];
      _originalReport = report;
      this.editReportId = editReportId;
      isRevisionMode = isRevision;

      // Prefill fields
      areaController.text = report.area;
      locationDetailController.text = report.detailLocation;
      mitraController.text = report.generalInfo['mitraName'] ?? '';
      staffNoteController.text = report.staffNote;

      // Populate checklist items
      for (int i = 0; i < _pekerjaan.checklistItems.length; i++) {
        final item = _pekerjaan.checklistItems[i];
        // find matching answer in report
        final matchingAnswer = report.checklistItems.firstWhere(
          (ans) => ans.itemId == item.id,
          orElse: () => QCChecklistAnswer(
            itemId: item.id,
            value: '',
            status: QCResultStatus.notFilled,
            photoPaths: [],
          ),
        );

        itemResults.add(matchingAnswer.value?.toString() ?? '');
        itemIssues.add(matchingAnswer.issueNote ?? '');
        itemPhotos.add(
          matchingAnswer.photoPaths
              .where(_isPersistablePhotoReference)
              .toList(),
        );
        pendingItemPhotos.add([]);
        pendingItemPhotoBytes.add([]);
        processingItemPhotos.add([]);
        itemStatuses.add(ChecklistStatus.belumDiisi);
        itemWarnings.add(null);
        itemAdminNotes.add(matchingAnswer.adminNote);
      }

      // Recalculate status for all prefilled items
      for (int i = 0; i < _pekerjaan.checklistItems.length; i++) {
        _recalculateStatus(i);
      }
    } else {
      // Initialize empty lists based on checklist items
      for (var _ in _pekerjaan.checklistItems) {
        itemStatuses.add(ChecklistStatus.belumDiisi);
        itemResults.add('');
        itemIssues.add('');
        itemPhotos.add([]);
        pendingItemPhotos.add([]);
        pendingItemPhotoBytes.add([]);
        processingItemPhotos.add([]);
        itemWarnings.add(null);
        itemAdminNotes.add(null);
      }
    }

    _isInit = true;
    notifyListeners();
  }

  String _newReportId() {
    final random = Random.secure();
    final randomPart = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'QC-WRK-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  void updateResult(int index, String value) {
    final item = _pekerjaan.checklistItems[index];
    final selectedOption = choiceOptionForValue(item.choiceOptions, value);
    if (item.inputType == InputType.choice &&
        selectedOption?.outcome == 'PASS') {
      itemIssues[index] = '';
    }
    itemResults[index] = value;
    _recalculateStatus(index);
    notifyListeners();
  }

  void updateIssueNote(int index, String value) {
    itemIssues[index] = value;
    _recalculateStatus(index);
    notifyListeners();
  }

  void _recalculateStatus(int index) {
    final item = _pekerjaan.checklistItems[index];
    final value = itemResults[index].trim();
    final hasPhotos =
        itemPhotos[index].isNotEmpty ||
        pendingItemPhotos[index].isNotEmpty ||
        processingItemPhotos[index].isNotEmpty;
    final issue = itemIssues[index].trim();

    if (value.isEmpty) {
      itemStatuses[index] = ChecklistStatus.belumDiisi;
      itemWarnings[index] = null;
      return;
    }

    if (item.inputType == InputType.number) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed == null) {
        itemStatuses[index] = ChecklistStatus.inputTidakValid;
        itemWarnings[index] = 'Input harus berupa angka';
        return;
      }
      if ((item.minValue != null && parsed < item.minValue!) ||
          (item.maxValue != null && parsed > item.maxValue!)) {
        itemStatuses[index] = ChecklistStatus.inputTidakValid;
        itemWarnings[index] = 'Nilai di luar batas yang diizinkan';
        return;
      }
    }

    // Check if required photo is missing
    final bool photoMissing =
        _submitAttempted && item.requiredPhoto && !hasPhotos;

    // Check if required note/issue is missing (when choice input is non-ideal)
    final bool isChoice = item.inputType == InputType.choice;
    final bool isNonIdeal =
        isChoice &&
        choiceOptionForValue(item.choiceOptions, value)?.outcome == 'FAIL';
    final bool noteMissing = isNonIdeal && issue.isEmpty;

    if (photoMissing) {
      itemStatuses[index] = ChecklistStatus.perluDilengkapi;
      itemWarnings[index] = 'Dokumentasi foto wajib diunggah';
    } else if (noteMissing) {
      itemStatuses[index] = ChecklistStatus.perluDilengkapi;
      itemWarnings[index] = 'Keterangan masalah wajib diisi';
    } else {
      itemStatuses[index] = ChecklistStatus.sudahDiisi;
      itemWarnings[index] = null;
    }
  }

  void updateStatus(int index, QCResultStatus status) {
    // No-op for staff-side QC Pekerjaan since staff doesn't evaluate status
  }

  Future<PhotoAddResult> addPhoto(int index) async {
    if (photoCount(index) >= maxPhotosPerItem) {
      return PhotoAddResult.limitReached;
    }
    if (!_photoCapturesInProgress.add(index)) return PhotoAddResult.cancelled;

    try {
      final XFile? selectedPhoto =
          await (photoPicker?.call(ImageSource.camera) ??
              _imagePicker.pickImage(source: ImageSource.camera));
      if (selectedPhoto == null) {
        return PhotoAddResult.cancelled;
      }
      if (_isDisposed) return PhotoAddResult.cancelled;

      if (photoCount(index) >= maxPhotosPerItem) {
        return PhotoAddResult.limitReached;
      }

      final processingEntry = QCPhotoProcessingEntry.fromCapture(
        id: '$index:${++_processingPhotoSequence}',
        source: selectedPhoto,
      );
      processingItemPhotos[index].add(processingEntry);
      if (!_isDisposed) notifyListeners();

      final QCProcessedPhoto processed;
      try {
        processed = await _photoProcessor.process(selectedPhoto);
      } on QCPhotoProcessingException {
        _removeProcessingEntry(index, processingEntry.id);
        return PhotoAddResult.fileTooLarge;
      } catch (_) {
        _removeProcessingEntry(index, processingEntry.id);
        rethrow;
      }
      if (_isDisposed || !_hasProcessingEntry(index, processingEntry.id)) {
        if (processed.isGenerated) {
          await _photoProcessor.deleteGeneratedFile(processed.file);
        }
        return PhotoAddResult.cancelled;
      }
      if (exceedsQCPhotoSizeLimit(processed.bytes)) {
        _removeProcessingEntry(index, processingEntry.id);
        if (processed.isGenerated) {
          await _photoProcessor.deleteGeneratedFile(processed.file);
        }
        return PhotoAddResult.fileTooLarge;
      }
      _removeProcessingEntry(index, processingEntry.id, notify: false);
      pendingItemPhotos[index].add(processed.file);
      pendingItemPhotoBytes[index].add(processed.bytes);
      _recalculateStatus(index);
      notifyListeners();
      return PhotoAddResult.added;
    } finally {
      _photoCapturesInProgress.remove(index);
    }
  }

  void removePhoto(int index, int photoIdx) {
    if (photoIdx < itemPhotos[index].length) {
      final removed = itemPhotos[index].removeAt(photoIdx);
      uploadedPhotoPreviewBytes.remove(removed);
    } else {
      final pendingIndex = photoIdx - itemPhotos[index].length;
      if (pendingIndex < pendingItemPhotos[index].length) {
        final removed = pendingItemPhotos[index].removeAt(pendingIndex);
        pendingItemPhotoBytes[index].removeAt(pendingIndex);
        _uploadedObjectPaths.remove(removed);
        unawaited(_photoProcessor.deleteGeneratedFile(removed));
      } else {
        final processingIndex =
            pendingIndex - pendingItemPhotos[index].length;
        processingItemPhotos[index].removeAt(processingIndex);
      }
    }
    _recalculateStatus(index);
    notifyListeners();
  }

  int photoCount(int index) =>
      itemPhotos[index].length +
      pendingItemPhotos[index].length +
      processingItemPhotos[index].length;

  bool _hasProcessingEntry(int itemIndex, String entryId) {
    return itemIndex < processingItemPhotos.length &&
        processingItemPhotos[itemIndex].any((entry) => entry.id == entryId);
  }

  void _removeProcessingEntry(
    int itemIndex,
    String entryId, {
    bool notify = true,
  }) {
    if (itemIndex >= processingItemPhotos.length) return;
    processingItemPhotos[itemIndex].removeWhere(
      (entry) => entry.id == entryId,
    );
    if (notify && !_isDisposed) notifyListeners();
  }

  bool get hasAnyDraftContent {
    return areaController.text.trim().isNotEmpty ||
        locationDetailController.text.trim().isNotEmpty ||
        mitraController.text.trim().isNotEmpty ||
        staffNoteController.text.trim().isNotEmpty ||
        itemResults.any((val) => val.trim().isNotEmpty) ||
        itemPhotos.any((photosList) => photosList.isNotEmpty) ||
        pendingItemPhotos.any((photosList) => photosList.isNotEmpty) ||
        processingItemPhotos.any((photosList) => photosList.isNotEmpty);
  }

  String? validateForm() {
    if (hasProcessingPhotos) return qcPhotoProcessingMessage;
    _submitAttempted = true;
    for (int i = 0; i < _pekerjaan.checklistItems.length; i++) {
      _recalculateStatus(i);
    }
    notifyListeners();

    for (int i = 0; i < _pekerjaan.checklistItems.length; i++) {
      final item = _pekerjaan.checklistItems[i];
      final valStr = itemResults[i].trim();
      final issue = itemIssues[i].trim();
      final hasPhotos =
          itemPhotos[i].isNotEmpty ||
          pendingItemPhotos[i].isNotEmpty ||
          processingItemPhotos[i].isNotEmpty;

      if (item.required && valStr.isEmpty) {
        if (item.inputType == InputType.number) {
          return 'Form ${i + 1} - ${item.title}: isi nilai aktual terlebih dahulu';
        } else if (item.inputType == InputType.choice) {
          return 'Form ${i + 1} - ${item.title}: pilih kesesuaian fisik terlebih dahulu';
        } else {
          return 'Form ${i + 1} - ${item.title}: isi hasil input terlebih dahulu';
        }
      }

      if (item.inputType == InputType.number) {
        if (!QCValidators.isValidNumber(valStr)) {
          return 'Form ${i + 1} - ${item.title}: masukkan angka yang valid';
        }
        final valNum = double.tryParse(valStr.replaceAll(',', '.'));
        if (valNum != null &&
            ((item.minValue != null && valNum < item.minValue!) ||
                (item.maxValue != null && valNum > item.maxValue!))) {
          return 'Form ${i + 1} - ${item.title}: nilai di luar batas yang diizinkan';
        }
      }

      if (item.requiredPhoto && !hasPhotos) {
        return 'Form ${i + 1} - ${item.title}: tambahkan dokumentasi foto terlebih dahulu';
      }

      final isNonIdeal =
          choiceOptionForValue(item.choiceOptions, valStr)?.outcome == 'FAIL';
      if (isNonIdeal && issue.isEmpty) {
        return 'Form ${i + 1} - ${item.title}: isi keterangan masalah terlebih dahulu';
      }
    }
    return null;
  }

  Future<void> persistReport(QCReportStatus status) async {
    if (_isPersisting) return;
    if (hasProcessingPhotos) {
      throw const ReportPersistenceException(qcPhotoProcessingMessage);
    }
    _isPersisting = true;
    notifyListeners();

    try {
      final persistedPhotos = await _uploadPendingPhotos();
      final workLoc = WorkLocation(
        siteName: _state.currentSite.name,
        area: areaController.text.isEmpty
            ? 'Sektor Utama'
            : areaController.text,
        segment: locationDetailController.text.isEmpty
            ? 'Titik Pekerjaan Lapangan'
            : locationDetailController.text,
        note: '',
        isCustom: false,
      );
      final answers = List<QCChecklistAnswer>.generate(
        _pekerjaan.checklistItems.length,
        (i) {
          final item = _pekerjaan.checklistItems[i];
          return QCChecklistAnswer(
            itemId: item.id,
            value: itemResults[i],
            status: QCResultStatus.notFilled,
            photoPaths: List<String>.unmodifiable(persistedPhotos[i]),
            paramName: item.title,
            standardText: item.standard,
            unit: item.unit,
            inputType: item.inputType == InputType.number
                ? 'number'
                : item.inputType == InputType.choice
                ? 'choice'
                : 'text',
            issueNote: itemIssues[i],
            adminNote: isRevisionMode ? itemAdminNotes[i] : null,
          );
        },
      );

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
          siteId: _originalReport!.siteId,
          siteName: _originalReport!.siteName,
          area: workLoc.area ?? '',
          detailLocation: workLoc.segment ?? '',
          checklistAnswers: answers,
          photos: [],
          staffNote: staffNoteController.text,
          adminNote: isRevisionMode ? null : _originalReport!.adminNote,
          adminReview: isRevisionMode
              ? AdminReview()
              : _originalReport!.adminReview,
          formCode: _originalReport!.formCode,
          templateId: _originalReport!.templateId,
          revisionNumber:
              _originalReport!.revisionNumber + (isRevisionMode ? 1 : 0),
          revisionHistory: updatedHistory,
        );
        final saved = await _apiService.patchReport(
          updatedReport,
          throwOnError: true,
        );
        if (!saved) {
          throw const ReportPersistenceException(
            'Laporan gagal disimpan. Periksa koneksi lalu coba lagi.',
          );
        }
        _commitPersistedPhotos(persistedPhotos);
        _state.updateReportLocally(updatedReport);
      } else {
        final newReport = QCReportModel(
          id: _reportId,
          title: '${_pekerjaan.name} - Inspeksi Lapangan',
          type: QCType.pekerjaan,
          status: status,
          checkedByName: _state.currentUser.name,
          checkedByNik: _state.currentUser.nik,
          date: DateTime.now(),
          siteId: _state.currentSite.id,
          siteName: _state.currentSite.name,
          area: workLoc.area ?? '',
          detailLocation: workLoc.segment ?? '',
          checklistAnswers: answers,
          photos: [],
          staffNote: staffNoteController.text,
          adminNote: status == QCReportStatus.DRAFT
              ? null
              : 'Menunggu review dari Admin.',
          formCode: 'PEK-CONST-01',
          templateId: _pekerjaan.id,
          revisionNumber: 1,
          revisionHistory: [],
        );
        final saved = await _apiService.postReport(
          newReport,
          throwOnError: true,
        );
        if (!saved) {
          throw const ReportPersistenceException(
            'Laporan gagal disimpan. Periksa koneksi lalu coba lagi.',
          );
        }
        _commitPersistedPhotos(persistedPhotos);
        _state.addReportLocally(newReport);
      }
    } on ReportPersistenceException {
      rethrow;
    } on ApiRequestException catch (error) {
      throw ReportPersistenceException(error.message);
    } catch (_) {
      throw const ReportPersistenceException(
        'Foto atau laporan gagal disimpan. Silakan coba lagi.',
      );
    } finally {
      _isPersisting = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<List<List<String>>> _uploadPendingPhotos() async {
    final persistedPhotos = itemPhotos
        .map((photos) => List<String>.from(photos))
        .toList();

    for (final photos in persistedPhotos) {
      if (photos.any((photo) => !_isPersistablePhotoReference(photo))) {
        throw const ReportPersistenceException(
          'Laporan memiliki referensi foto yang tidak valid.',
        );
      }
    }

    for (int itemIndex = 0; itemIndex < pendingItemPhotos.length; itemIndex++) {
      final itemId = _pekerjaan.checklistItems[itemIndex].id;
      while (pendingItemPhotos[itemIndex].isNotEmpty) {
        final photo = pendingItemPhotos[itemIndex].first;
        final previewBytes = pendingItemPhotoBytes[itemIndex].first;
        var objectPath = _uploadedObjectPaths[photo];
        if (objectPath == null) {
          final bytes = await photo.readAsBytes();
          if (exceedsQCPhotoSizeLimit(bytes)) {
            throw const ReportPersistenceException(qcPhotoTooLargeMessage);
          }
          final uploaded = await _apiService.uploadQCEvidence(
            file: photo,
            reportId: _reportId,
            itemId: itemId,
          );
          objectPath = uploaded.objectPath;
          if (!_isCanonicalObjectPath(objectPath)) {
            throw const ReportPersistenceException(
              'Server mengembalikan referensi foto yang tidak valid.',
            );
          }
          _uploadedObjectPaths[photo] = objectPath;
        }
        itemPhotos[itemIndex].add(objectPath);
        uploadedPhotoPreviewBytes[objectPath] = previewBytes;
        pendingItemPhotos[itemIndex].removeAt(0);
        pendingItemPhotoBytes[itemIndex].removeAt(0);
        unawaited(_photoProcessor.deleteGeneratedFile(photo));
        persistedPhotos[itemIndex].add(objectPath);
        if (!_isDisposed) notifyListeners();
      }
    }
    return persistedPhotos;
  }

  void _commitPersistedPhotos(List<List<String>> persistedPhotos) {
    for (int i = 0; i < itemPhotos.length; i++) {
      itemPhotos[i]
        ..clear()
        ..addAll(persistedPhotos[i]);
      pendingItemPhotos[i].clear();
      pendingItemPhotoBytes[i].clear();
    }
  }

  bool _isPersistablePhotoReference(String value) =>
      _isCanonicalObjectPath(value) || _isSupportedLegacyUrl(value);

  bool _isCanonicalObjectPath(String value) => RegExp(
    r'^reports/[A-Za-z0-9_-]{1,128}/(?:general/[0-9a-f-]{36}|checklist/[A-Za-z0-9_-]{1,128}/[0-9a-f-]{36})\.(?:jpg|png|webp|heic)$',
  ).hasMatch(value);

  bool _isSupportedLegacyUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    return !uri.path.contains('/storage/v1/object/sign/');
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final photos in pendingItemPhotos) {
      for (final photo in photos) {
        unawaited(_photoProcessor.deleteGeneratedFile(photo));
      }
    }
    for (final photos in processingItemPhotos) {
      photos.clear();
    }
    _isPersisting = false;
    areaController.dispose();
    locationDetailController.dispose();
    mitraController.dispose();
    staffNoteController.dispose();
    super.dispose();
  }
}
