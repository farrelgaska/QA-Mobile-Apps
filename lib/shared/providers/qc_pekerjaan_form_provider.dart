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
    }
    _isInit = true;
    notifyListeners();
  }

  void updateResult(int index, String value) {
    itemResults[index] = value;
    // Auto validation for numeric type
    final item = _pekerjaan.checklistItems[index];
    if (item.inputType == InputType.number && !QCValidators.isValidNumber(value)) {
      // keep status as belumDiisi, warning handled elsewhere
    }
    // compute auto status (similar to original logic)
    itemStatuses[index] = _calculateAutoStatus(item, value);
    notifyListeners();
  }

  void updateStatus(int index, QCResultStatus status) {
    // Map QCResultStatus back to ChecklistStatus
    ChecklistStatus cs;
    switch (status) {
      case QCResultStatus.pass:
        cs = ChecklistStatus.lulus;
        break;
      case QCResultStatus.fail:
        cs = ChecklistStatus.tidakSesuai;
        break;
      case QCResultStatus.needFollowUp:
        cs = ChecklistStatus.perluTindakLanjut;
        break;
      default:
        cs = ChecklistStatus.belumDiisi;
    }
    itemStatuses[index] = cs;
    notifyListeners();
  }

  void addPhoto(int index) {
    final mockUrls = [
      'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=150&q=80',
      'https://images.unsplash.com/photo-1590069261209-f8e9b8642343?auto=format&fit=crop&w=150&q=80',
    ];
    final url = mockUrls[itemPhotos[index].length % mockUrls.length];
    itemPhotos[index].add(url);
    notifyListeners();
  }

  void removePhoto(int index, int photoIdx) {
    itemPhotos[index].removeAt(photoIdx);
    notifyListeners();
  }

  String? validateForm() {
    // Basic non‑list validation could be added here if needed
    for (int i = 0; i < _pekerjaan.checklistItems.length; i++) {
      final item = _pekerjaan.checklistItems[i];
      final valStr = itemResults[i].trim();
      final isChoiceOrBool = item.inputType == InputType.choice;
      if (valStr.isEmpty) {
        if (item.inputType == InputType.number) {
          return 'Form ${i+1} - ${item.title}: isi nilai aktual terlebih dahulu';
        } else if (isChoiceOrBool) {
          return 'Form ${i+1} - ${item.title}: pilih kesesuaian fisik terlebih dahulu';
        } else {
          return 'Form ${i+1} - ${item.title}: isi hasil input terlebih dahulu';
        }
      }
      if (item.inputType == InputType.number && !QCValidators.isValidNumber(valStr)) {
        return 'Form ${i+1} - ${item.title}: masukkan angka yang valid';
      }
      if (itemPhotos[i].isEmpty) {
        return 'Form ${i+1} - ${item.title}: tambahkan dokumentasi foto terlebih dahulu';
      }
      final bool isNonIdeal = valStr == 'Tidak' ||
          valStr == 'Tidak Sesuai' ||
          itemStatuses[i] == ChecklistStatus.tidakSesuai ||
          itemStatuses[i] == ChecklistStatus.perluTindakLanjut ||
          (isChoiceOrBool &&
              !['sesuai', 'rapi', 'kencang', 'ada', 'lengkap', 'ya', 'ok', 'diterima', 'sesuai standar']
                  .contains(valStr.toLowerCase()));
      if (isNonIdeal && (itemIssues[i].trim().isEmpty)) {
        return 'Form ${i+1} - ${item.title}: wajib mengisi keterangan masalah karena nilai berada di luar standar / tidak sesuai';
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
      adminNote: status == QCReportStatus.draft ? null : 'Menunggu review dari Admin.',
      workLocation: workLoc,
    );
    _state.addReport(newReport);
  }

  ChecklistStatus _calculateAutoStatus(dynamic item, String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) return ChecklistStatus.belumDiisi;
    if (item.inputType == InputType.number) {
      final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
      if (parsed == null) return ChecklistStatus.belumDiisi;
      final lower = item.title.toLowerCase();
      if (lower.contains('redaman')) {
        return (parsed >= -24 && parsed <= -15) ? ChecklistStatus.lulus : ChecklistStatus.tidakSesuai;
      }
      if (lower.contains('kedalaman')) {
        return (parsed >= 1.2) ? ChecklistStatus.lulus : ChecklistStatus.tidakSesuai;
      }
      // generic numeric passes
      return ChecklistStatus.lulus;
    } else if (item.inputType == InputType.choice) {
      final lower = trimmed.toLowerCase();
      const passKeywords = ['sesuai', 'rapi', 'kencang', 'bersih', 'ada & jelas', 'tegak lurus', 'sesuai standar', 'lengkap', 'ya', 'ok'];
      return passKeywords.contains(lower) ? ChecklistStatus.lulus : ChecklistStatus.tidakSesuai;
    } else {
      return ChecklistStatus.lulus;
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
