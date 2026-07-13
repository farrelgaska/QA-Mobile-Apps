import 'package:flutter/material.dart';
import '../../core/dummy/dummy_pekerjaan.dart';
import '../../core/dummy/dummy_state.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/qc_report_model.dart'; // QCReportModel, AdminReview
import '../../shared/models/qc_checklist_answer_model.dart';
import '../../shared/models/work_location_model.dart';
import '../../core/utils/validators.dart';

class QCPekerjaanFormProvider extends ChangeNotifier {
  final DummyState _state = DummyState();
  bool _isInit = false;
  dynamic _pekerjaan; // dummy model

  /// Public getters for UI consumption
  bool get isReady => _isInit;
  dynamic get pekerjaan => _pekerjaan;
  DummyState get state => _state;

  // General controllers
  final TextEditingController areaController = TextEditingController();
  final TextEditingController locationDetailController = TextEditingController();
  final TextEditingController mitraController = TextEditingController();
  final TextEditingController staffNoteController = TextEditingController();

  // Checklist state
  final List<ChecklistStatus> itemStatuses = [];
  final List<String> itemResults = [];
  final List<String> itemIssues = [];
  final List<List<String>> itemPhotos = [];
  final List<String?> itemWarnings = [];
  final List<String?> itemAdminNotes = [];

  // Revision state
  bool isRevisionMode = false;
  String? editReportId;
  QCReportModel? _originalReport;

  void init(String pekerjaanId, {String? editReportId, bool isRevision = false}) {
    if (_isInit) return;
    _pekerjaan = dummyPekerjaan.firstWhere((p) => p.id == pekerjaanId,
        orElse: () => dummyPekerjaan[0]);

    if (editReportId != null) {
      final report = _state.reports.firstWhere((r) => r.id == editReportId,
          orElse: () => _state.reports[0]);
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
        itemPhotos.add(List<String>.from(matchingAnswer.photoPaths));
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
        itemWarnings.add(null);
        itemAdminNotes.add(null);
      }
    }

    _isInit = true;
    notifyListeners();
  }

  void updateResult(int index, String value) {
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
    final photos = itemPhotos[index];
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
      if (parsed < 0) {
        itemStatuses[index] = ChecklistStatus.inputTidakValid;
        itemWarnings[index] = 'Nilai tidak boleh negatif';
        return;
      }
    }

    // Check if required photo is missing
    final bool photoMissing = item.requiredPhoto && photos.isEmpty;

    // Check if required note/issue is missing (when choice input is non-ideal)
    final bool isChoice = item.inputType == InputType.choice;
    final bool isNonIdeal = isChoice &&
        !['sesuai', 'rapi', 'kencang', 'ada', 'lengkap', 'ya', 'ok', 'diterima', 'sesuai standar', 'bersih', 'ada & jelas', 'tegak lurus'].contains(value.toLowerCase());
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

  void addPhoto(int index) {
    final mockUrls = [
      'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=150&q=80',
      'https://images.unsplash.com/photo-1590069261209-f8e9b8642343?auto=format&fit=crop&w=150&q=80',
    ];
    final url = mockUrls[itemPhotos[index].length % mockUrls.length];
    itemPhotos[index].add(url);
    _recalculateStatus(index);
    notifyListeners();
  }

  void removePhoto(int index, int photoIdx) {
    itemPhotos[index].removeAt(photoIdx);
    _recalculateStatus(index);
    notifyListeners();
  }

  bool get hasAnyDraftContent {
    return areaController.text.trim().isNotEmpty ||
           locationDetailController.text.trim().isNotEmpty ||
           mitraController.text.trim().isNotEmpty ||
           staffNoteController.text.trim().isNotEmpty ||
           itemResults.any((val) => val.trim().isNotEmpty) ||
           itemPhotos.any((photosList) => photosList.isNotEmpty);
  }

  String? validateForm() {
    for (int i = 0; i < _pekerjaan.checklistItems.length; i++) {
      final item = _pekerjaan.checklistItems[i];
      final valStr = itemResults[i].trim();
      final issue = itemIssues[i].trim();
      final photos = itemPhotos[i];

      if (valStr.isEmpty) {
        if (item.inputType == InputType.number) {
          return 'Form ${i+1} - ${item.title}: isi nilai aktual terlebih dahulu';
        } else if (item.inputType == InputType.choice) {
          return 'Form ${i+1} - ${item.title}: pilih kesesuaian fisik terlebih dahulu';
        } else {
          return 'Form ${i+1} - ${item.title}: isi hasil input terlebih dahulu';
        }
      }

      if (item.inputType == InputType.number) {
        if (!QCValidators.isValidNumber(valStr)) {
          return 'Form ${i+1} - ${item.title}: masukkan angka yang valid';
        }
        final valNum = double.tryParse(valStr.replaceAll(',', '.'));
        if (valNum != null && valNum < 0) {
          return 'Form ${i+1} - ${item.title}: nilai tidak boleh negatif';
        }
      }

      if (item.requiredPhoto && photos.isEmpty) {
        return 'Form ${i+1} - ${item.title}: tambahkan dokumentasi foto terlebih dahulu';
      }

      final isChoice = item.inputType == InputType.choice;
      final isNonIdeal = isChoice &&
          !['sesuai', 'rapi', 'kencang', 'ada', 'lengkap', 'ya', 'ok', 'diterima', 'sesuai standar', 'bersih', 'ada & jelas', 'tegak lurus'].contains(valStr.toLowerCase());
      if (isNonIdeal && issue.isEmpty) {
        return 'Form ${i+1} - ${item.title}: isi keterangan masalah terlebih dahulu';
      }
    }
    return null;
  }

  void persistReport(QCReportStatus status) {
    final workLoc = WorkLocation(
      siteName: _state.currentSite.name,
      area: areaController.text.isEmpty ? 'Sektor Utama' : areaController.text,
      segment: locationDetailController.text.isEmpty ? 'Titik Pekerjaan Lapangan' : locationDetailController.text,
      note: '',
      isCustom: false,
    );
    final answers = List<QCChecklistAnswer>.generate(_pekerjaan.checklistItems.length, (i) {
      final item = _pekerjaan.checklistItems[i];
      return QCChecklistAnswer(
        itemId: item.id,
        value: itemResults[i],
        status: QCResultStatus.notFilled,
        photoPaths: itemPhotos[i],
        paramName: item.title,
        standardText: item.standard,
        unit: item.unit,
        inputType: item.inputType == InputType.number ? 'number' : item.inputType == InputType.choice ? 'choice' : 'text',
        issueNote: itemIssues[i],
        adminNote: isRevisionMode ? itemAdminNotes[i] : null,
      );
    });

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
        siteId: _originalReport!.siteId,
        siteName: _originalReport!.siteName,
        area: workLoc.area ?? '',
        detailLocation: workLoc.segment ?? '',
        checklistAnswers: answers,
        photos: [],
        staffNote: staffNoteController.text,
        adminNote: null, // clear Admin note — Admin will re-evaluate
        adminReview: AdminReview(), // reset Admin review for fresh evaluation
        formCode: _originalReport!.formCode,
        templateId: _originalReport!.templateId,
        revisionNumber: _originalReport!.revisionNumber + 1,
        revisionHistory: updatedHistory,
      );
      _state.updateReport(updatedReport);
    } else {
      final newReport = QCReportModel(
        id: 'QC-WRK-${DateTime.now().year}-${1000 + _state.reports.length}',
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
        adminNote: status == QCReportStatus.DRAFT ? null : 'Menunggu review dari Admin.',
        formCode: 'PEK-CONST-01',
        templateId: _pekerjaan.id,
        revisionNumber: 1,
        revisionHistory: [],
      );
      _state.addReport(newReport);
    }
  }

  @override
  void dispose() {
    areaController.dispose();
    locationDetailController.dispose();
    mitraController.dispose();
    staffNoteController.dispose();
    super.dispose();
  }
}
