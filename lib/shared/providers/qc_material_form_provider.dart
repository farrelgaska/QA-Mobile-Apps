import 'package:flutter/material.dart';
import '../../core/dummy/dummy_qc_material_templates.dart';
import '../../core/dummy/dummy_state.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/qc_report_model.dart';
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
  late SiteModel selectedSite;
  bool isCustomLocation = false;
  final TextEditingController customLocNameController = TextEditingController();
  final TextEditingController customLocAreaController = TextEditingController();
  final TextEditingController customLocSegmentController = TextEditingController();
  final TextEditingController customLocNoteController = TextEditingController();

  // Checklist answers
  final List<QCChecklistAnswer> answers = [];

  void init(String materialId) {
    if (_isInit) return;
    _template = dummyQCMaterialTemplates.firstWhere((t) => t.id == materialId,
        orElse: () => dummyQCMaterialTemplates[0]);
    // Prepopulate template fields
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
      ));
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
    // Re‑validate to clear any photo‑required warning
    final item = _template.checklistItems[index];
    final valRes = QCValidationHelper.validateChecklistAnswer(item: item, value: answers[index].value);
    answers[index].warningMessage = valRes.warningMessage;
    notifyListeners();
  }

  void removePhoto(int index, int photoIdx) {
    answers[index].photoPaths.removeAt(photoIdx);
    // Re‑validate
    final item = _template.checklistItems[index];
    final valRes = QCValidationHelper.validateChecklistAnswer(item: item, value: answers[index].value);
    answers[index].warningMessage = valRes.warningMessage;
    notifyListeners();
  }

  String? validateForm() {
    // General info validation (same as original _validateFormFirstError subset)
    if (poNumberController.text.trim().isEmpty) return 'Isi nomor PO terlebih dahulu';
    if (doNumberController.text.trim().isEmpty) return 'Isi nomor DO terlebih dahulu';
    if (vendorNameController.text.trim().isEmpty) return 'Isi nama vendor terlebih dahulu';
    if (arrivalVolumeController.text.trim().isEmpty) return 'Isi volume datang terlebih dahulu';
    if (samplingVolumeController.text.trim().isEmpty) return 'Isi volume sampling terlebih dahulu';
    if (brandNameController.text.trim().isEmpty) return 'Isi merk material terlebih dahulu';
    if (warehouseLocationController.text.trim().isEmpty) return 'Isi lokasi warehouse terlebih dahulu';
    if (isCustomLocation) {
      if (customLocNameController.text.trim().isEmpty) return 'Isi nama lokasi kustom terlebih dahulu';
      if (customLocAreaController.text.trim().isEmpty) return 'Isi area/zona lokasi kustom terlebih dahulu';
      if (customLocSegmentController.text.trim().isEmpty) return 'Isi titik/segmen lokasi kustom terlebih dahulu';
    }
    for (int i = 0; i < _template.checklistItems.length; i++) {
      final item = _template.checklistItems[i];
      final answer = answers[i];
      final formNumber = i + 1;
      final valStr = answer.value.trim();
      final isChoiceOrBool = item.inputType == QCInputType.choice || item.inputType == QCInputType.booleanCheck;
      if (valStr.isEmpty) {
        if (item.inputType == QCInputType.number) {
          return 'Form $formNumber - ${item.label}: isi nilai aktual terlebih dahulu';
        } else if (isChoiceOrBool) {
          return 'Form $formNumber - ${item.label}: pilih kesesuaian fisik terlebih dahulu';
        } else {
          return 'Form $formNumber - ${item.label}: isi hasil input terlebih dahulu';
        }
      }
      if (item.inputType == QCInputType.number && !QCValidators.isValidNumber(valStr)) {
        return 'Form $formNumber - ${item.label}: masukkan angka yang valid';
      }
      if (answer.photoPaths.isEmpty) {
        return 'Form $formNumber - ${item.label}: tambahkan dokumentasi foto terlebih dahulu';
      }
      final bool isNonIdeal = valStr == 'Tidak' ||
          valStr == 'Tidak Sesuai' ||
          answer.status == QCResultStatus.fail ||
          (item.inputType == QCInputType.choice &&
              !['sesuai', 'rapi', 'kencang', 'ada', 'lengkap', 'ya', 'ok', 'diterima', 'sesuai standar']
                  .contains(valStr.toLowerCase()));
      if (isNonIdeal && (answer.issueNote == null || answer.issueNote!.trim().isEmpty)) {
        return 'Form $formNumber - ${item.label}: wajib mengisi keterangan masalah karena nilai berada di luar standar / tidak sesuai';
      }
    }
    return null;
  }

  void persistReport(QCReportStatus status) {
    final workLoc = WorkLocation(
      siteName: isCustomLocation ? customLocNameController.text : selectedSite.name,
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
    final newReport = QCReportModel(
      id: 'QC-MAT-${DateTime.now().year}-${1000 + _state.reports.length}',
      title: _template.name,
      type: QCType.material,
      status: status,
      checkedByName: _state.currentUser.name,
      checkedByNik: _state.currentUser.nik,
      date: DateTime.now(),
      siteId: isCustomLocation ? 'custom-site' : selectedSite.id,
      siteName: workLoc.siteName,
      area: workLoc.area ?? '',
      detailLocation: workLoc.segment ?? '',
      checklistAnswers: answers.map((a) => a.copyWith(status: QCResultStatus.notFilled)).toList(),
      photos: [],
      staffNote: staffNoteController.text,
      adminNote: status == QCReportStatus.draft ? null : 'Menunggu review dari Admin.',
      formCode: _template.code,
      workLocation: workLoc,
      generalInfo: genInfo,
      finalConclusion: status == QCReportStatus.draft ? 'Belum Lengkap' : 'Pending',
    );
    _state.addReport(newReport);
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
