import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/dummy/dummy_state.dart';
import '../../core/dummy/dummy_sites.dart';
import '../../core/services/api_service.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/qc_report_model.dart'; // QCReportModel, AdminReview, StaffIdentity, ReportLocation
import '../../shared/models/qc_report_sample_model.dart';
import '../../shared/models/qc_checklist_answer_model.dart';
import '../../shared/models/qc_material_template_model.dart';
import '../../shared/models/qc_material_evaluation_model.dart';
import '../../shared/models/qc_photo_processing_entry.dart';
import '../../shared/models/work_location_model.dart';
import '../../shared/models/site_model.dart';
import '../../shared/utils/qc_photo_validation.dart';
import '../../shared/services/qc_photo_processor.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/qc_validation_helper.dart';
import '../../shared/models/template_choice_option.dart';

enum QCMaterialPhotoAddResult { added, cancelled, fileTooLarge }

enum QCMaterialGeneralField {
  poNumber,
  poDate,
  doNumber,
  vendorName,
  materialId,
  arrivalVolume,
  samplingVolume,
  sampleCount,
  brandName,
  warehouseLocation,
  stelVersion,
  qaExpiryDate,
  tkdnNumber,
  tkdnCertDate,
  tkdnValue,
  workLocation,
  customLocationName,
  customLocationArea,
  customLocationSegment,
}

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

class QCMaterialSampleState {
  final String id;
  final int sampleNumber;
  QCSampleInspectionStatus inspectionStatus;
  final List<QCChecklistAnswer> answers;
  final TextEditingController notesController;
  final List<String> photoPaths;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<List<XFile>> localItemPhotos;
  final List<List<Uint8List>> localItemPhotoBytes;
  final List<List<QCPhotoProcessingEntry>> processingItemPhotos;

  QCMaterialSampleState({
    required this.id,
    required this.sampleNumber,
    required this.inspectionStatus,
    required this.answers,
    required String notes,
    required this.photoPaths,
    required this.createdAt,
    required this.updatedAt,
  }) : notesController = TextEditingController(text: notes),
       localItemPhotos = List.generate(answers.length, (_) => <XFile>[]),
       localItemPhotoBytes = List.generate(
         answers.length,
         (_) => <Uint8List>[],
       ),
       processingItemPhotos = List.generate(
         answers.length,
         (_) => <QCPhotoProcessingEntry>[],
       );

  bool get hasContent =>
      notesController.text.trim().isNotEmpty ||
      photoPaths.isNotEmpty ||
      answers.any(
        (answer) => answer.value?.toString().trim().isNotEmpty == true,
      ) ||
      answers.any((answer) => answer.photoPaths.isNotEmpty) ||
      localItemPhotos.any((photos) => photos.isNotEmpty) ||
      processingItemPhotos.any((photos) => photos.isNotEmpty);

  void dispose() {
    notesController.dispose();
  }
}

class QCMaterialFormProvider extends ChangeNotifier {
  // Dependencies
  final DummyState _state = DummyState();
  final ImagePicker _imagePicker;
  final Future<XFile?> Function(ImageSource source)? photoPicker;
  final QCMaterialPersistenceApi _api;
  final QCPhotoProcessor _photoProcessor;
  final Map<XFile, String> _uploadedObjectPaths = {};
  final Set<String> _photoCapturesInProgress = <String>{};
  int _processingPhotoSequence = 0;
  bool _isPersisting = false;
  bool _isNavigating = false;
  bool _isDisposed = false;
  late String _reportId;
  final Map<QCMaterialGeneralField, String> _generalFieldErrors = {};
  QCMaterialSamplingDecision? _samplingDecision;

  static const _sampleStatusesKey = 'qcSampleEvaluationStatuses';
  static const _failedSampleCountKey = 'qcFailedSampleCount';
  static const _reviewEligibleKey = 'qcReviewRequestEligible';

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
  bool get isNavigating => _isNavigating;
  Map<QCMaterialGeneralField, String> get generalFieldErrors =>
      Map.unmodifiable(_generalFieldErrors);
  QCMaterialGeneralField? get firstInvalidGeneralField =>
      _generalFieldErrors.keys.firstOrNull;
  bool get hasProcessingPhotos => samples.any(
    (sample) => sample.processingItemPhotos.any((photos) => photos.isNotEmpty),
  );
  String get reportId => _reportId;
  QCMaterialTemplate get template => _template;
  QCMaterialSamplingDecision? get samplingDecision => _samplingDecision;
  bool get hasSamplingDecision => _samplingDecision != null;
  bool get isSamplingStopped =>
      _samplingDecision?.type == QCMaterialSamplingDecisionType.stop;

  /// All samples whose evaluation status is OUT_OF_STANDARD.
  List<QCMaterialSampleState> get outOfStandardSamples => samples
      .where(
        (sample) =>
            sampleEvaluationStatus(sample) ==
            QCSampleEvaluationStatus.outOfStandard,
      )
      .toList(growable: false);
  int get failedSampleCount => outOfStandardSamples.length;

  /// Completed samples whose evaluation status is OUT_OF_STANDARD.
  List<QCMaterialSampleState> get failedCompletedSamples => samples
      .where(
        (sample) =>
            sample.inspectionStatus == QCSampleInspectionStatus.completed &&
            sampleEvaluationStatus(sample) ==
                QCSampleEvaluationStatus.outOfStandard,
      )
      .toList(growable: false);
  int get failedCompletedCount => failedCompletedSamples.length;

  /// True when at least 2 completed samples are out-of-standard and no
  /// decision has been recorded yet. Does not depend on total sample count.
  bool get isSamplingDecisionRequired =>
      !hasSamplingDecision && failedCompletedCount >= 2;
  bool get isSamplingWarningActive =>
      isSamplingDecisionRequired || hasSamplingDecision;
  QCSampleEvaluationStatus get currentSampleEvaluationStatus {
    final sample = currentSample;
    return sample == null
        ? QCSampleEvaluationStatus.notEvaluated
        : sampleEvaluationStatus(sample);
  }

  // Controllers for general info
  final TextEditingController poNumberController = TextEditingController();
  final TextEditingController poDateController = TextEditingController();
  final TextEditingController doNumberController = TextEditingController();
  final TextEditingController vendorNameController = TextEditingController();
  final TextEditingController materialIdController = TextEditingController();
  final TextEditingController arrivalVolumeController = TextEditingController();
  final TextEditingController samplingVolumeController =
      TextEditingController();
  final TextEditingController sampleCountController = TextEditingController(
    text: '1',
  );
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
    _generalFieldErrors.remove(QCMaterialGeneralField.workLocation);
    notifyListeners();
  }

  void setIsCustomLocation(bool val) {
    isCustomLocation = val;
    _clearLocationErrors();
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

  String? generalFieldError(QCMaterialGeneralField field) =>
      _generalFieldErrors[field];

  void clearGeneralFieldError(QCMaterialGeneralField field) {
    if (_generalFieldErrors.remove(field) != null) notifyListeners();
  }

  void _clearLocationErrors() {
    _generalFieldErrors.remove(QCMaterialGeneralField.workLocation);
    _generalFieldErrors.remove(QCMaterialGeneralField.customLocationName);
    _generalFieldErrors.remove(QCMaterialGeneralField.customLocationArea);
    _generalFieldErrors.remove(QCMaterialGeneralField.customLocationSegment);
  }

  String? validateLocation() {
    if (isCustomLocation) {
      if (customLocNameController.text.trim().isEmpty) {
        return 'Isi lokasi custom terlebih dahulu.';
      }
      if (customLocAreaController.text.trim().isEmpty) {
        return 'Isi area atau zona lokasi custom terlebih dahulu.';
      }
      if (customLocSegmentController.text.trim().isEmpty) {
        return 'Isi titik atau segmen lokasi custom terlebih dahulu.';
      }
      return null;
    }
    if (selectedSite == null) {
      return 'Pilih lokasi kerja terlebih dahulu.';
    }
    return null;
  }

  String? validateGeneralInformation() {
    _generalFieldErrors.clear();

    final requiredFields = <QCMaterialGeneralField, (String, String)>{
      QCMaterialGeneralField.poNumber: (poNumberController.text, 'Nomor PO'),
      QCMaterialGeneralField.poDate: (poDateController.text, 'Tanggal PO'),
      QCMaterialGeneralField.doNumber: (
        doNumberController.text,
        'Nomor DO / Surat Jalan',
      ),
      QCMaterialGeneralField.vendorName: (
        vendorNameController.text,
        'Nama Mitra Pabrikasi / Vendor',
      ),
      QCMaterialGeneralField.materialId: (
        materialIdController.text,
        'ID Material',
      ),
      QCMaterialGeneralField.arrivalVolume: (
        arrivalVolumeController.text,
        'Volume Datang',
      ),
      QCMaterialGeneralField.samplingVolume: (
        samplingVolumeController.text,
        'Volume Sampling',
      ),
      QCMaterialGeneralField.sampleCount: (
        sampleCountController.text,
        'Jumlah Sampel',
      ),
      QCMaterialGeneralField.brandName: (
        brandNameController.text,
        'Merk Material',
      ),
      QCMaterialGeneralField.warehouseLocation: (
        warehouseLocationController.text,
        'Lokasi Warehouse Penerima',
      ),
      QCMaterialGeneralField.stelVersion: (
        stelVersionController.text,
        'Nomor QA/STEL/Versi',
      ),
      QCMaterialGeneralField.qaExpiryDate: (
        qaExpiryDateController.text,
        'Masa Berlaku QA',
      ),
      QCMaterialGeneralField.tkdnNumber: (
        tkdnNumberController.text,
        'Nomor Sertifikat TKDN',
      ),
      QCMaterialGeneralField.tkdnCertDate: (
        tkdnCertDateController.text,
        'Tanggal Sertifikat TKDN',
      ),
      QCMaterialGeneralField.tkdnValue: (
        tkdnValueController.text,
        'Nilai TKDN',
      ),
    };

    for (final entry in requiredFields.entries) {
      if (entry.value.$1.trim().isEmpty) {
        _generalFieldErrors[entry.key] = '${entry.value.$2} wajib diisi.';
      }
    }

    _validateGeneralNumber(
      QCMaterialGeneralField.arrivalVolume,
      arrivalVolumeController.text,
      'Volume Datang',
    );
    _validateGeneralNumber(
      QCMaterialGeneralField.samplingVolume,
      samplingVolumeController.text,
      'Volume Sampling',
    );
    _validateGeneralNumber(
      QCMaterialGeneralField.tkdnValue,
      tkdnValueController.text,
      'Nilai TKDN',
    );

    final sampleCountValue = sampleCountController.text.trim();
    final requestedCount = int.tryParse(sampleCountValue);
    if (sampleCountValue.isNotEmpty &&
        (requestedCount == null || requestedCount <= 0)) {
      _generalFieldErrors[QCMaterialGeneralField.sampleCount] =
          'Jumlah sampel harus berupa bilangan bulat positif.';
    }

    if (isCustomLocation) {
      if (customLocNameController.text.trim().isEmpty) {
        _generalFieldErrors[QCMaterialGeneralField.customLocationName] =
            'Nama lokasi wajib diisi.';
      }
      if (customLocAreaController.text.trim().isEmpty) {
        _generalFieldErrors[QCMaterialGeneralField.customLocationArea] =
            'Area atau zona wajib diisi.';
      }
      if (customLocSegmentController.text.trim().isEmpty) {
        _generalFieldErrors[QCMaterialGeneralField.customLocationSegment] =
            'Titik atau segmen wajib diisi.';
      }
    } else if (selectedSite == null) {
      _generalFieldErrors[QCMaterialGeneralField.workLocation] =
          'Pilih lokasi kerja terlebih dahulu.';
    }

    return _generalFieldErrors.values.firstOrNull;
  }

  void _validateGeneralNumber(
    QCMaterialGeneralField field,
    String rawValue,
    String label,
  ) {
    if (rawValue.trim().isEmpty) return;
    if (!QCValidators.isValidNumber(rawValue)) {
      _generalFieldErrors[field] = '$label harus berupa angka yang valid.';
      return;
    }
    final value = double.tryParse(rawValue.trim().replaceAll(',', '.'));
    if (value != null && value < 0) {
      _generalFieldErrors[field] = '$label tidak boleh negatif.';
    }
  }

  // Ordered sample state. Legacy checklist getters expose the active sample.
  final List<QCMaterialSampleState> samples = [];
  int _sampleCount = 1;
  int _currentStep = 0;

  int get sampleCount => _sampleCount;
  int get currentStep => _currentStep;
  int get totalSteps => _sampleCount + 1;
  bool get isGeneralStep => _currentStep == 0;
  bool get isFirstStep => _currentStep == 0;
  bool get isFinalStep => _currentStep == totalSteps - 1;
  int? get currentSampleIndex => isGeneralStep ? null : _currentStep - 1;
  QCMaterialSampleState? get currentSample =>
      isGeneralStep ? null : samples[currentSampleIndex!];
  List<QCChecklistAnswer> get answers =>
      currentSample?.answers ?? samples.first.answers;
  List<List<XFile>> get localItemPhotos =>
      currentSample?.localItemPhotos ?? samples.first.localItemPhotos;
  List<List<Uint8List>> get localItemPhotoBytes =>
      currentSample?.localItemPhotoBytes ?? samples.first.localItemPhotoBytes;
  List<List<QCPhotoProcessingEntry>> get processingItemPhotos =>
      currentSample?.processingItemPhotos ?? samples.first.processingItemPhotos;

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
      sampleCountController.text = report.sampleCount.toString();
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

      samples.clear();
      _samplingDecision = QCMaterialSamplingDecision.fromGeneralInfo(
        report.generalInfo,
      );
      if (report.samples.isNotEmpty) {
        for (final sample in report.samples) {
          samples.add(
            QCMaterialSampleState(
              id: sample.id,
              sampleNumber: sample.sampleNumber,
              inspectionStatus: sample.inspectionStatus,
              answers: _answersFromSnapshot(sample.checklistAnswers),
              notes: sample.notes,
              photoPaths: List<String>.from(sample.photoPaths),
              createdAt: sample.createdAt,
              updatedAt: sample.updatedAt,
            ),
          );
        }
        _sampleCount = max(report.sampleCount, samples.length);
      } else {
        _sampleCount = report.sampleCount > 0 ? report.sampleCount : 1;
        final legacyAnswers = _answersFromSnapshot(report.checklistItems);
        samples.add(
          _newSampleState(
            1,
            answers: legacyAnswers,
            inspectionStatus:
                legacyAnswers.any(
                  (answer) =>
                      answer.value?.toString().trim().isNotEmpty == true,
                )
                ? QCSampleInspectionStatus.inProgress
                : QCSampleInspectionStatus.notStarted,
          ),
        );
      }
      _appendMissingSamples();
      _currentStep = _restoredStep(report);
    } else {
      _samplingDecision = null;
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
      sampleCountController.text = '1';

      _sampleCount = 1;
      _currentStep = 0;
      samples
        ..clear()
        ..add(_newSampleState(1));
    }

    _isInit = true;
    notifyListeners();
  }

  QCSampleEvaluationStatus sampleEvaluationStatus(
    QCMaterialSampleState sample,
  ) {
    if (sample.answers.any(
      (answer) =>
          qcSampleEvaluationStatusFromValue(answer.evaluationStatus) ==
          QCSampleEvaluationStatus.outOfStandard,
    )) {
      return QCSampleEvaluationStatus.outOfStandard;
    }

    final answersByItemId = {
      for (final answer in sample.answers) answer.itemId: answer,
    };
    final requiredEvaluableItems = _template.checklistItems.where(
      (item) => item.required && item.isActive && _isParameterEvaluable(item),
    );
    if (requiredEvaluableItems.isEmpty) {
      return QCSampleEvaluationStatus.notEvaluated;
    }
    final allWithinStandard = requiredEvaluableItems.every((item) {
      final answer = answersByItemId[item.id];
      return answer != null &&
          qcSampleEvaluationStatusFromValue(answer.evaluationStatus) ==
              QCSampleEvaluationStatus.withinStandard;
    });
    return allWithinStandard
        ? QCSampleEvaluationStatus.withinStandard
        : QCSampleEvaluationStatus.notEvaluated;
  }

  void setParameterEvaluationStatus({
    required int sampleIndex,
    required int answerIndex,
    required QCSampleEvaluationStatus status,
  }) {
    final sample = samples[sampleIndex];
    sample.answers[answerIndex].evaluationStatus = status.apiValue;
    sample.updatedAt = DateTime.now();
    notifyListeners();
  }

  String? recordSamplingDecision({
    required QCMaterialSamplingDecisionType decision,
    String? stopReason,
    DateTime? decidedAt,
  }) {
    if (hasSamplingDecision) {
      return 'Keputusan sampling sudah dicatat.';
    }
    if (!isSamplingDecisionRequired) {
      return 'Keputusan sampling belum diperlukan.';
    }
    final normalizedReason = stopReason?.trim() ?? '';
    if (decision == QCMaterialSamplingDecisionType.stop &&
        normalizedReason.isEmpty) {
      return 'Alasan penghentian wajib diisi.';
    }
    final failedSamples = failedCompletedSamples;
    _samplingDecision = QCMaterialSamplingDecision(
      type: decision,
      decidedAt: decidedAt ?? DateTime.now(),
      stopReason: decision == QCMaterialSamplingDecisionType.stop
          ? normalizedReason
          : null,
      failedSampleIds: List.unmodifiable(
        failedSamples.map((sample) => sample.id),
      ),
      failedSampleNumbers: List.unmodifiable(
        failedSamples.map((sample) => sample.sampleNumber),
      ),
    );
    notifyListeners();
    return null;
  }

  QCMaterialSampleState _newSampleState(
    int sampleNumber, {
    List<QCChecklistAnswer>? answers,
    QCSampleInspectionStatus inspectionStatus =
        QCSampleInspectionStatus.notStarted,
  }) {
    final now = DateTime.now();
    return QCMaterialSampleState(
      id: '$_reportId-sample-$sampleNumber',
      sampleNumber: sampleNumber,
      inspectionStatus: inspectionStatus,
      answers:
          answers ??
          _template.checklistItems
              .map(_emptyAnswerForItem)
              .toList(growable: false),
      notes: '',
      photoPaths: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  QCChecklistAnswer _emptyAnswerForItem(QCChecklistItem item) {
    return QCChecklistAnswer(
      itemId: item.id,
      value: '',
      status: QCResultStatus.notFilled,
      photoPaths: [],
      paramName: item.label,
      standardText: item.standardText,
      unit: item.unit,
      inputType: _inputTypeValue(item.inputType),
    );
  }

  List<QCChecklistAnswer> _answersFromSnapshot(
    List<QCChecklistAnswer> snapshot,
  ) {
    final byItemId = {for (final answer in snapshot) answer.itemId: answer};
    return _template.checklistItems
        .map((item) {
          final matchingAnswer = byItemId[item.id];
          if (matchingAnswer == null) return _emptyAnswerForItem(item);
          final value = matchingAnswer.value?.toString() ?? '';
          final validation = QCValidationHelper.validateChecklistAnswer(
            item: item,
            value: value,
          );
          return matchingAnswer.copyWith(
            paramName: item.label,
            standardText: matchingAnswer.standardText.isEmpty
                ? item.standardText
                : matchingAnswer.standardText,
            unit: matchingAnswer.unit ?? item.unit,
            inputType: _inputTypeValue(item.inputType),
            warningMessage: validation.warningMessage,
            status: validation.status,
            photoPaths: List<String>.unmodifiable(matchingAnswer.photoPaths),
          );
        })
        .toList(growable: false);
  }

  String _inputTypeValue(QCInputType inputType) => switch (inputType) {
    QCInputType.number => 'number',
    QCInputType.choice => 'choice',
    QCInputType.booleanCheck => 'boolean',
    _ => 'text',
  };

  void _appendMissingSamples() {
    while (samples.length < _sampleCount) {
      final nextNumber = samples.isEmpty
          ? 1
          : samples.map((sample) => sample.sampleNumber).reduce(max) + 1;
      samples.add(_newSampleState(nextNumber));
    }
  }

  int _restoredStep(QCReportModel report) {
    final stored = int.tryParse(report.generalInfo['currentStep'] ?? '');
    if (stored != null && stored >= 0 && stored < totalSteps) {
      // When stopped, do not allow navigating beyond the last completed sample.
      return isSamplingStopped ? min(stored, _lastAllowedStep) : stored;
    }
    final incompleteIndex = samples.indexWhere(
      (sample) => sample.inspectionStatus != QCSampleInspectionStatus.completed,
    );
    final restored = incompleteIndex >= 0
        ? incompleteIndex + 1
        : totalSteps - 1;
    return isSamplingStopped ? min(restored, _lastAllowedStep) : restored;
  }

  /// The last sample step index the user may navigate to while stopped.
  /// Equals the index of the last completed sample, or step 1 if none.
  int get _lastAllowedStep {
    for (var i = samples.length - 1; i >= 0; i--) {
      if (samples[i].inspectionStatus == QCSampleInspectionStatus.completed) {
        return i + 1;
      }
    }
    return 1;
  }

  String _newReportId() {
    final random = Random.secure();
    final randomPart = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'QC-MAT-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  void updateAnswer(int index, dynamic value) {
    final item = _template.checklistItems[index];
    final valueText = value?.toString() ?? '';
    final selectedOption = choiceOptionForValue(item.choiceOptions, valueText);
    if (item.inputType == QCInputType.choice &&
        selectedOption?.outcome == 'PASS') {
      answers[index].issueNote = '';
    }
    answers[index].value = value;
    final valRes = QCValidationHelper.validateChecklistAnswer(
      item: item,
      value: valueText,
    );
    answers[index].warningMessage = valRes.warningMessage;
    answers[index].status = valRes.status;
    answers[index].evaluationStatus = _evaluateParameter(
      item,
      valueText,
    ).apiValue;
    _markCurrentSampleInProgress();
    notifyListeners();
  }

  bool _isParameterEvaluable(QCChecklistItem item) {
    return switch (item.inputType) {
      QCInputType.number =>
        item.minValue != null ||
            item.maxValue != null ||
            item.validationRule?.minValue != null ||
            item.validationRule?.maxValue != null,
      QCInputType.choice => _resolvedChoiceOptions(item).isNotEmpty,
      QCInputType.booleanCheck => true,
      QCInputType.text || QCInputType.photo => false,
    };
  }

  QCSampleEvaluationStatus _evaluateParameter(
    QCChecklistItem item,
    String rawValue,
  ) {
    final value = rawValue.trim();
    if (value.isEmpty || !_isParameterEvaluable(item)) {
      return QCSampleEvaluationStatus.notEvaluated;
    }

    switch (item.inputType) {
      case QCInputType.number:
        final actual = double.tryParse(value.replaceAll(',', '.'));
        if (actual == null || !actual.isFinite) {
          return QCSampleEvaluationStatus.notEvaluated;
        }
        final minimum = item.minValue ?? item.validationRule?.minValue;
        final maximum = item.maxValue ?? item.validationRule?.maxValue;
        if ((minimum != null && actual < minimum) ||
            (maximum != null && actual > maximum)) {
          return QCSampleEvaluationStatus.outOfStandard;
        }
        return QCSampleEvaluationStatus.withinStandard;
      case QCInputType.choice:
        final option = choiceOptionForValue(
          _resolvedChoiceOptions(item),
          value,
        );
        return switch (option?.outcome.toUpperCase()) {
          'PASS' => QCSampleEvaluationStatus.withinStandard,
          'FAIL' => QCSampleEvaluationStatus.outOfStandard,
          _ => QCSampleEvaluationStatus.notEvaluated,
        };
      case QCInputType.booleanCheck:
        if (value == 'Tidak' || value == 'Tidak Sesuai') {
          return QCSampleEvaluationStatus.outOfStandard;
        }
        if (value == 'Ya' || value == 'Sesuai' || value == 'OK') {
          return QCSampleEvaluationStatus.withinStandard;
        }
        return QCSampleEvaluationStatus.notEvaluated;
      case QCInputType.text:
      case QCInputType.photo:
        return QCSampleEvaluationStatus.notEvaluated;
    }
  }

  List<TemplateChoiceOption> _resolvedChoiceOptions(QCChecklistItem item) {
    if (item.choiceOptions.isNotEmpty) return item.choiceOptions;
    return (item.choices ?? const <String>[])
        .asMap()
        .entries
        .map(
          (entry) => TemplateChoiceOption(
            id: 'legacy-choice-${entry.key}',
            label: entry.value,
            value: entry.value,
            outcome: entry.key == 0 ? 'PASS' : 'FAIL',
            position: entry.key,
          ),
        )
        .toList(growable: false);
  }

  Future<QCMaterialPhotoAddResult> addPhoto(int index) async {
    final activeSample = currentSample ?? samples.first;
    final captureKey = '${activeSample.id}:$index';
    if (!_photoCapturesInProgress.add(captureKey)) {
      return QCMaterialPhotoAddResult.cancelled;
    }
    try {
      final selectedPhoto =
          await (photoPicker?.call(ImageSource.camera) ??
              _imagePicker.pickImage(source: ImageSource.camera));
      if (selectedPhoto == null) return QCMaterialPhotoAddResult.cancelled;
      if (_isDisposed) return QCMaterialPhotoAddResult.cancelled;

      final processingEntry = QCPhotoProcessingEntry.fromCapture(
        id: '$captureKey:${++_processingPhotoSequence}',
        source: selectedPhoto,
      );
      activeSample.processingItemPhotos[index].add(processingEntry);
      if (!_isDisposed) notifyListeners();

      final QCProcessedPhoto processed;
      try {
        processed = await _photoProcessor.process(selectedPhoto);
      } on QCPhotoProcessingException {
        _removeProcessingEntry(activeSample, index, processingEntry.id);
        return QCMaterialPhotoAddResult.fileTooLarge;
      } catch (_) {
        _removeProcessingEntry(activeSample, index, processingEntry.id);
        rethrow;
      }
      if (_isDisposed ||
          !_hasProcessingEntry(activeSample, index, processingEntry.id)) {
        if (processed.isGenerated) {
          await _photoProcessor.deleteGeneratedFile(processed.file);
        }
        return QCMaterialPhotoAddResult.cancelled;
      }
      if (exceedsQCPhotoSizeLimit(processed.bytes)) {
        _removeProcessingEntry(activeSample, index, processingEntry.id);
        if (processed.isGenerated) {
          await _photoProcessor.deleteGeneratedFile(processed.file);
        }
        return QCMaterialPhotoAddResult.fileTooLarge;
      }
      _removeProcessingEntry(
        activeSample,
        index,
        processingEntry.id,
        notify: false,
      );
      activeSample.localItemPhotos[index].add(processed.file);
      activeSample.localItemPhotoBytes[index].add(processed.bytes);
      activeSample.updatedAt = DateTime.now();
      if (activeSample.inspectionStatus ==
          QCSampleInspectionStatus.notStarted) {
        activeSample.inspectionStatus = QCSampleInspectionStatus.inProgress;
      }
      notifyListeners();
      return QCMaterialPhotoAddResult.added;
    } finally {
      _photoCapturesInProgress.remove(captureKey);
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
      if (localIndex < localItemPhotos[index].length) {
        final removed = localItemPhotos[index].removeAt(localIndex);
        localItemPhotoBytes[index].removeAt(localIndex);
        _uploadedObjectPaths.remove(removed);
        unawaited(_photoProcessor.deleteGeneratedFile(removed));
      } else {
        final processingIndex = localIndex - localItemPhotos[index].length;
        processingItemPhotos[index].removeAt(processingIndex);
      }
    }
    _markCurrentSampleInProgress();
    notifyListeners();
  }

  bool _hasProcessingEntry(
    QCMaterialSampleState sample,
    int itemIndex,
    String entryId,
  ) {
    return samples.contains(sample) &&
        itemIndex < sample.processingItemPhotos.length &&
        sample.processingItemPhotos[itemIndex].any(
          (entry) => entry.id == entryId,
        );
  }

  void _removeProcessingEntry(
    QCMaterialSampleState sample,
    int itemIndex,
    String entryId, {
    bool notify = true,
  }) {
    if (itemIndex >= sample.processingItemPhotos.length) return;
    sample.processingItemPhotos[itemIndex].removeWhere(
      (entry) => entry.id == entryId,
    );
    if (notify && !_isDisposed) notifyListeners();
  }

  void updateIssueNote(int index, String value) {
    answers[index].issueNote = value;
    _markCurrentSampleInProgress();
    notifyListeners();
  }

  void updateSampleNotes(String value) {
    final sample = currentSample;
    if (sample == null) return;
    sample.updatedAt = DateTime.now();
    if (value.trim().isNotEmpty &&
        sample.inspectionStatus == QCSampleInspectionStatus.notStarted) {
      sample.inspectionStatus = QCSampleInspectionStatus.inProgress;
    }
    notifyListeners();
  }

  void _markCurrentSampleInProgress() {
    final sample = currentSample ?? samples.first;
    sample.updatedAt = DateTime.now();
    if (sample.inspectionStatus == QCSampleInspectionStatus.notStarted) {
      sample.inspectionStatus = QCSampleInspectionStatus.inProgress;
    }
  }

  bool get hasAnyDraftContent {
    return poNumberController.text.trim().isNotEmpty ||
        doNumberController.text.trim().isNotEmpty ||
        vendorNameController.text.trim().isNotEmpty ||
        staffNoteController.text.trim().isNotEmpty ||
        samples.any((sample) => sample.hasContent);
  }

  String? validateSample(int sampleIndex) {
    final sample = samples[sampleIndex];
    for (int i = 0; i < _template.checklistItems.length; i++) {
      final item = _template.checklistItems[i];
      final valStr = sample.answers[i].value?.toString().trim() ?? '';
      final issue = sample.answers[i].issueNote?.trim() ?? '';
      final photos = sample.answers[i].photoPaths;

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

      if (item.requiredPhoto &&
          photos.isEmpty &&
          sample.localItemPhotos[i].isEmpty &&
          sample.processingItemPhotos[i].isEmpty) {
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

  String? validateCurrentStep() {
    if (isGeneralStep) {
      final generalError = validateGeneralInformation();
      if (generalError != null) return generalError;
      final sampleCountError = _synchronizeSampleCount();
      if (sampleCountError != null) {
        _generalFieldErrors[QCMaterialGeneralField.sampleCount] =
            sampleCountError;
      }
      return sampleCountError;
    }
    return validateSample(currentSampleIndex!);
  }

  String? validateForm() {
    final generalError = validateLocation();
    if (generalError != null) return generalError;
    for (var index = 0; index < samples.length; index++) {
      final error = validateSample(index);
      if (error != null) return 'Sampel ${index + 1}: $error';
    }
    return null;
  }

  String? _synchronizeSampleCount() {
    final rawValue = sampleCountController.text.trim();
    final requestedCount = int.tryParse(rawValue);
    if (requestedCount == null || requestedCount <= 0) {
      return 'Jumlah sampel harus berupa bilangan bulat positif.';
    }
    if (requestedCount < samples.length) {
      final removedSamples = samples.skip(requestedCount);
      if (removedSamples.any((sample) => sample.hasContent)) {
        return 'Jumlah sampel tidak dapat dikurangi karena data sampel sudah diisi.';
      }
      for (final sample in removedSamples) {
        _disposeSampleState(sample);
      }
      samples.removeRange(requestedCount, samples.length);
    }
    _sampleCount = requestedCount;
    _appendMissingSamples();
    if (_currentStep >= totalSteps) _currentStep = totalSteps - 1;
    return null;
  }

  void _disposeSampleState(QCMaterialSampleState sample) {
    for (final photos in sample.localItemPhotos) {
      for (final photo in photos) {
        unawaited(_photoProcessor.deleteGeneratedFile(photo));
      }
    }
    for (final photos in sample.processingItemPhotos) {
      photos.clear();
    }
    sample.dispose();
  }

  Future<String?> nextStep() async {
    if (_isNavigating || isFinalStep) return null;
    if (isSamplingStopped && _currentStep >= _lastAllowedStep) {
      return 'Pemeriksaan telah dihentikan. Sampel tambahan tidak dapat dibuka.';
    }
    _isNavigating = true;
    notifyListeners();
    try {
      final validationError = validateCurrentStep();
      if (validationError != null) return validationError;
      if (!isGeneralStep) {
        final sample = currentSample!;
        sample.inspectionStatus = QCSampleInspectionStatus.completed;
        sample.updatedAt = DateTime.now();
        if (isSamplingDecisionRequired) return null;
      }
      await Future<void>.delayed(Duration.zero);
      if (_currentStep < totalSteps - 1) _currentStep++;
      return null;
    } finally {
      _isNavigating = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> previousStep() async {
    if (_isNavigating || isFirstStep) return;
    _isNavigating = true;
    notifyListeners();
    try {
      await Future<void>.delayed(Duration.zero);
      if (_currentStep > 0) _currentStep--;
    } finally {
      _isNavigating = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  void completeCurrentSample() {
    final sample = currentSample;
    if (sample == null) return;
    sample.inspectionStatus = QCSampleInspectionStatus.completed;
    sample.updatedAt = DateTime.now();
    notifyListeners();
  }

  List<QCChecklistAnswer> _snapshotAnswersByItemId(
    QCMaterialSampleState sample,
    List<List<String>> persistedPhotos,
  ) {
    final answersByItemId = {
      for (final answer in sample.answers) answer.itemId: answer,
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
          return _emptyAnswerForItem(item);
        })
        .toList(growable: false);
  }

  Future<void> persistReport(QCReportStatus status) async {
    if (_isPersisting) return;
    if (hasProcessingPhotos) {
      throw const QCMaterialPersistenceException(qcPhotoProcessingMessage);
    }
    final sampleCountError = _synchronizeSampleCount();
    if (sampleCountError != null) {
      throw QCMaterialPersistenceException(sampleCountError);
    }
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
    List<List<List<String>>> persistedPhotos,
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
      'currentStep': _currentStep.toString(),
      _sampleStatusesKey: jsonEncode({
        for (final sample in samples)
          sample.id: sampleEvaluationStatus(sample).apiValue,
      }),
      _failedSampleCountKey: failedSampleCount.toString(),
      _reviewEligibleKey: isSamplingWarningActive.toString(),
    };
    _samplingDecision?.writeToGeneralInfo(genInfo);
    final sampleSnapshots = List<QCReportSample>.generate(samples.length, (
      index,
    ) {
      final sample = samples[index];
      if (sample.photoPaths.any(
        (photo) => !_isCanonicalObjectPath(photo) && !_isHttpUrl(photo),
      )) {
        throw const QCMaterialPersistenceException(
          'Laporan memiliki referensi foto sampel yang tidak valid.',
        );
      }
      final canonicalSamplePhotos = sample.photoPaths
          .where(_isCanonicalObjectPath)
          .toList(growable: false);
      return QCReportSample(
        id: sample.id,
        sampleNumber: sample.sampleNumber,
        inspectionStatus: sample.inspectionStatus,
        checklistAnswers: _snapshotAnswersByItemId(
          sample,
          persistedPhotos[index],
        ),
        notes: sample.notesController.text,
        photoPaths: canonicalSamplePhotos,
        createdAt: sample.createdAt,
        updatedAt: sample.updatedAt,
      );
    });
    final answerSnapshot = sampleSnapshots.first.checklistAnswers;

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
        sampleCount: _sampleCount,
        samples: sampleSnapshots,
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
        sampleCount: _sampleCount,
        samples: sampleSnapshots,
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
      _originalReport = newReport;
      _state.addReportLocally(newReport);
    }
  }

  Future<List<List<List<String>>>> _uploadPendingPhotos() async {
    final persistedBySample = <List<List<String>>>[];
    for (final sample in samples) {
      final answersByItemId = {
        for (final answer in sample.answers) answer.itemId: answer,
      };
      final persistedPhotos = _template.checklistItems
          .map(
            (item) => List<String>.from(
              answersByItemId[item.id]?.photoPaths ?? const <String>[],
            ),
          )
          .toList(growable: false);

      for (var itemIndex = 0; itemIndex < persistedPhotos.length; itemIndex++) {
        final photos = persistedPhotos[itemIndex];
        if (photos.any(
          (photo) => !_isCanonicalObjectPath(photo) && !_isHttpUrl(photo),
        )) {
          throw const QCMaterialPersistenceException(
            'Laporan memiliki referensi foto yang tidak valid.',
          );
        }
        persistedPhotos[itemIndex] = photos
            .where(_isCanonicalObjectPath)
            .toList();

        final itemId = _template.checklistItems[itemIndex].id;
        for (final photo in sample.localItemPhotos[itemIndex]) {
          var objectPath = _uploadedObjectPaths[photo];
          if (objectPath == null) {
            final bytes = await photo.readAsBytes();
            if (exceedsQCPhotoSizeLimit(bytes)) {
              throw const QCMaterialPersistenceException(
                qcPhotoTooLargeMessage,
              );
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
      persistedBySample.add(persistedPhotos);
    }
    return persistedBySample;
  }

  void _commitPersistedPhotos(List<List<List<String>>> persistedBySample) {
    for (var sampleIndex = 0; sampleIndex < samples.length; sampleIndex++) {
      final sample = samples[sampleIndex];
      final persistedPhotos = persistedBySample[sampleIndex];
      final photosByItemId = <String, List<String>>{};
      for (
        var itemIndex = 0;
        itemIndex < _template.checklistItems.length;
        itemIndex++
      ) {
        photosByItemId[_template.checklistItems[itemIndex].id] =
            persistedPhotos[itemIndex];
        for (final photo in sample.localItemPhotos[itemIndex]) {
          unawaited(_photoProcessor.deleteGeneratedFile(photo));
        }
        sample.localItemPhotos[itemIndex].clear();
        sample.localItemPhotoBytes[itemIndex].clear();
      }
      for (
        var answerIndex = 0;
        answerIndex < sample.answers.length;
        answerIndex++
      ) {
        final answer = sample.answers[answerIndex];
        sample.answers[answerIndex] = answer.copyWith(
          photoPaths: List<String>.from(
            photosByItemId[answer.itemId] ?? const <String>[],
          ),
        );
      }
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
    for (final sample in samples) {
      _disposeSampleState(sample);
    }
    _isPersisting = false;
    poNumberController.dispose();
    poDateController.dispose();
    doNumberController.dispose();
    vendorNameController.dispose();
    materialIdController.dispose();
    arrivalVolumeController.dispose();
    samplingVolumeController.dispose();
    sampleCountController.dispose();
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
