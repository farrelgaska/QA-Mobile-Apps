import 'package:flutter/material.dart';
import '../../core/dummy/dummy_pekerjaan.dart';
import '../../core/dummy/dummy_state.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/qc_report_model.dart';
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

  void init(String pekerjaanId) {
    if (_isInit) return;
    _pekerjaan = dummyPekerjaan.firstWhere((p) => p.id == pekerjaanId,
        orElse: () => dummyPekerjaan[0]);
    // Initialize lists based on checklist items
    for (var _ in _pekerjaan.checklistItems) {
      itemStatuses.add(ChecklistStatus.belumDiisi);
      itemResults.add('');
      itemIssues.add('');
      itemPhotos.add([]);
      itemWarnings.add(null);
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
    final results = List<QCReportChecklistResult>.generate(_pekerjaan.checklistItems.length, (i) {
      final item = _pekerjaan.checklistItems[i];
      return QCReportChecklistResult(
        itemId: item.id,
        paramName: item.title,
        standard: item.standard,
        inputType: item.inputType == InputType.number ? 'Angka' : item.inputType == InputType.choice ? 'Pilihan' : 'Teks',
        unit: item.unit,
        resultValue: itemResults[i],
        status: itemStatuses[i],
        issueNote: itemIssues[i],
        photos: itemPhotos[i],
      );
    });
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
      checklistResults: results,
      photos: [],
      staffNote: staffNoteController.text,
      adminNote: status == QCReportStatus.DRAFT ? null : 'Menunggu review dari Admin.',
      workLocation: workLoc,
    );
    _state.addReport(newReport);
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
