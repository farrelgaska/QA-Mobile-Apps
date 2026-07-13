import 'package:flutter/material.dart';
import '../../core/dummy/dummy_qc_material_templates.dart';
import '../../core/dummy/dummy_state.dart';
import '../../core/dummy/dummy_sites.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/qc_report_model.dart'; // QCReportModel, AdminReview, StaffIdentity, ReportLocation
import '../../shared/models/qc_checklist_answer_model.dart';
import '../../shared/models/qc_material_template_model.dart';
import '../../shared/models/work_location_model.dart';
import '../../shared/models/site_model.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/qc_validation_helper.dart';

class QCMaterialFormProvider extends ChangeNotifier {
  // Dependencies
  final DummyState _state = DummyState();

  // Template
  late QCMaterialTemplate _template;
  bool _isInit = false;

  /// Public getters for UI consumption
  bool get isReady => _isInit;
  QCMaterialTemplate get template => _template;

  // Controllers for general info
  final TextEditingController poNumberController = TextEditingController();
  final TextEditingController poDateController = TextEditingController();
  final TextEditingController doNumberController = TextEditingController();
  final TextEditingController vendorNameController = TextEditingController();
  final TextEditingController materialIdController = TextEditingController();
  final TextEditingController arrivalVolumeController = TextEditingController();
  final TextEditingController samplingVolumeController = TextEditingController();
  final TextEditingController brandNameController = TextEditingController();
  final TextEditingController warehouseLocationController = TextEditingController();
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
  final TextEditingController customLocSegmentController = TextEditingController();
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

  // Revision state
  bool isRevisionMode = false;
  String? editReportId;
  QCReportModel? _originalReport;

  void init(String materialId, {String? editReportId, bool isRevision = false}) {
    if (_isInit) return;
    _template = dummyQCMaterialTemplates.firstWhere((t) => t.id == materialId,
        orElse: () => dummyQCMaterialTemplates[0]);

    if (editReportId != null) {
      final report = _state.reports.firstWhere((r) => r.id == editReportId,
          orElse: () => _state.reports[0]);
      _originalReport = report;
      this.editReportId = editReportId;
      isRevisionMode = isRevision;

      // Prefill fields
      poNumberController.text = report.generalInfo['poNumber'] ?? '';
      poDateController.text = report.generalInfo['poDate'] ?? '';
      doNumberController.text = report.generalInfo['doNumber'] ?? '';
      vendorNameController.text = report.generalInfo['vendorName'] ?? '';
      materialIdController.text = report.generalInfo['materialId'] ?? report.templateId;
      arrivalVolumeController.text = report.generalInfo['arrivalVolume'] ?? '';
      samplingVolumeController.text = report.generalInfo['samplingVolume'] ?? '';
      brandNameController.text = report.generalInfo['brandName'] ?? '';
      warehouseLocationController.text = report.generalInfo['warehouseLocation'] ?? '';
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
        selectedSite = dummySites.firstWhere((s) => s.id == report.location.siteId,
            orElse: () => dummySites[0]);
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
            inputType: item.inputType == QCInputType.number ? 'number' : item.inputType == QCInputType.choice ? 'choice' : 'text',
          ),
        );
        
        // Recalculate warning message / status locally
        final valRes = QCValidationHelper.validateChecklistAnswer(item: item, value: matchingAnswer.value?.toString() ?? '');
        answers.add(matchingAnswer.copyWith(
          warningMessage: valRes.warningMessage,
          status: valRes.status,
        ));
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
        answers.add(QCChecklistAnswer(
          itemId: item.id,
          value: '',
          status: QCResultStatus.notFilled,
          photoPaths: [],
          paramName: item.label,
          standardText: item.standardText,
          unit: item.unit,
          inputType: item.inputType == QCInputType.number ? 'number' : item.inputType == QCInputType.choice ? 'choice' : 'text',
        ));
      }
    }

    _isInit = true;
    notifyListeners();
  }

  void updateAnswer(int index, String value) {
    final item = _template.checklistItems[index];
    answers[index].value = value;
    final valRes = QCValidationHelper.validateChecklistAnswer(item: item, value: value);
    answers[index].warningMessage = valRes.warningMessage;
    answers[index].status = valRes.status;
    notifyListeners();
  }

  void addPhoto(int index) {
    final mockUrls = [
      'https://images.unsplash.com/photo-1590066070792-4aa7d9bf5df7?auto=format&fit=crop&w=150&q=80',
      'https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?auto=format&fit=crop&w=150&q=80',
    ];
    final url = mockUrls[answers[index].photoPaths.length % mockUrls.length];
    answers[index].photoPaths.add(url);
    notifyListeners();
  }

  void removePhoto(int index, int photoIdx) {
    answers[index].photoPaths.removeAt(photoIdx);
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
           answers.any((a) => a.photoPaths.isNotEmpty);
  }

  String? validateForm() {
    for (int i = 0; i < _template.checklistItems.length; i++) {
      final item = _template.checklistItems[i];
      final valStr = answers[i].value.toString().trim();
      final issue = answers[i].issueNote?.trim() ?? '';
      final photos = answers[i].photoPaths;

      if (valStr.isEmpty) {
        if (item.inputType == QCInputType.number) {
          return 'Form ${i+1} - ${item.label}: isi nilai pengujian terlebih dahulu';
        } else if (item.inputType == QCInputType.choice) {
          return 'Form ${i+1} - ${item.label}: pilih kesesuaian fisik terlebih dahulu';
        } else {
          return 'Form ${i+1} - ${item.label}: isi hasil input terlebih dahulu';
        }
      }

      if (item.inputType == QCInputType.number) {
        if (!QCValidators.isValidNumber(valStr)) {
          return 'Form ${i+1} - ${item.label}: masukkan angka yang valid';
        }
        final valNum = double.tryParse(valStr.replaceAll(',', '.'));
        if (valNum != null && valNum < 0) {
          return 'Form ${i+1} - ${item.label}: nilai tidak boleh negatif';
        }
      }

      if (item.requiredPhoto && photos.isEmpty) {
        return 'Form ${i+1} - ${item.label}: tambahkan dokumentasi foto terlebih dahulu';
      }

      final isChoice = item.inputType == QCInputType.choice;
      final isNonIdeal = isChoice &&
          !['sesuai', 'rapi', 'kencang', 'ada', 'lengkap', 'ya', 'ok', 'diterima', 'sesuai standar', 'bersih', 'ada & jelas', 'tegak lurus'].contains(valStr.toLowerCase());
      if (isNonIdeal && issue.isEmpty) {
        return 'Form ${i+1} - ${item.label}: isi keterangan masalah terlebih dahulu';
      }
    }
    return null;
  }

  void persistReport(QCReportStatus status) {
    final workLoc = WorkLocation(
      siteName: isCustomLocation ? customLocNameController.text : (selectedSite?.name ?? 'Site Utama'),
      area: isCustomLocation ? customLocAreaController.text : 'Area Site Utama',
      segment: isCustomLocation ? customLocSegmentController.text : 'Segmen Default',
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

    if (isRevisionMode && _originalReport != null) {
      final updatedHistory = List<QCReportModel>.from(_originalReport!.revisionHistory);
      updatedHistory.add(_originalReport!);

      final updatedReport = QCReportModel(
        id: _originalReport!.id,
        title: _originalReport!.title,
        type: _originalReport!.type,
        status: QCReportStatus.SUBMITTED,
        checkedByName: _state.currentUser.name,
        checkedByNik: _state.currentUser.nik,
        date: DateTime.now(), // submittedAt updated on resubmit
        siteId: isCustomLocation ? 'custom-site' : (selectedSite?.id ?? 'custom-site'),
        siteName: workLoc.siteName,
        area: workLoc.area ?? '',
        detailLocation: workLoc.segment ?? '',
        checklistAnswers: answers.map((a) => a.copyWith(status: QCResultStatus.notFilled)).toList(),
        photos: [],
        staffNote: staffNoteController.text,
        adminNote: null, // clear Admin note — Admin will re-evaluate
        adminReview: AdminReview(), // reset Admin review for fresh evaluation
        formCode: _originalReport!.formCode,
        templateId: _originalReport!.templateId,
        generalInfo: genInfo,
        revisionNumber: _originalReport!.revisionNumber + 1,
        revisionHistory: updatedHistory,
      );
      _state.updateReport(updatedReport);
    } else {
      final newReport = QCReportModel(
        id: 'QC-MAT-${DateTime.now().year}-${1000 + _state.reports.length}',
        title: _template.name,
        type: QCType.material,
        status: status,
        checkedByName: _state.currentUser.name,
        checkedByNik: _state.currentUser.nik,
        date: DateTime.now(),
        siteId: isCustomLocation ? 'custom-site' : (selectedSite?.id ?? 'custom-site'),
        siteName: workLoc.siteName,
        area: workLoc.area ?? '',
        detailLocation: workLoc.segment ?? '',
        checklistAnswers: answers.map((a) => a.copyWith(status: QCResultStatus.notFilled)).toList(),
        photos: [],
        staffNote: staffNoteController.text,
        adminNote: status == QCReportStatus.DRAFT ? null : 'Menunggu review dari Admin.',
        formCode: _template.code,
        templateId: _template.id,
        generalInfo: genInfo,
        finalConclusion: status == QCReportStatus.DRAFT ? 'Belum Lengkap' : 'Pending',
        revisionNumber: 1,
        revisionHistory: [],
      );
      _state.addReport(newReport);
    }
  }

  @override
  void dispose() {
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
