import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_pekerjaan.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/checklist_item_model.dart';
import '../../../shared/models/qc_report_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/checklist_item_card.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/confirmation_modal.dart';

class QCPekerjaanFormScreen extends StatefulWidget {
  final String pekerjaanId;

  const QCPekerjaanFormScreen({
    Key? key,
    required this.pekerjaanId,
  }) : super(key: key);

  @override
  State<QCPekerjaanFormScreen> createState() => _QCPekerjaanFormScreenState();
}

class _QCPekerjaanFormScreenState extends State<QCPekerjaanFormScreen> {
  final _state = DummyState();
  
  // Form controllers
  final _areaController = TextEditingController();
  final _locationDetailController = TextEditingController();
  final _mitraController = TextEditingController();
  final _staffNoteController = TextEditingController();

  // Checklist state variables
  final List<ChecklistStatus> _itemStatuses = [];
  final List<String> _itemResults = [];
  final List<String> _itemIssues = [];
  final List<List<String>> _itemPhotos = [];

  bool _isInit = false;
  dynamic _pekerjaan;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      // Find pekerjaan
      _pekerjaan = dummyPekerjaan.firstWhere(
        (p) => p.id == widget.pekerjaanId,
        orElse: () => dummyPekerjaan[0],
      );

      // Initialize lists matching checklist items
      for (var _ in _pekerjaan.checklistItems) {
        _itemStatuses.add(ChecklistStatus.lulus);
        _itemResults.add('');
        _itemIssues.add('');
        _itemPhotos.add([]);
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    _locationDetailController.dispose();
    _mitraController.dispose();
    _staffNoteController.dispose();
    super.dispose();
  }

  void _simulatePhotoUpload(int index) {
    final mockUrls = [
      'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=150&q=80',
      'https://images.unsplash.com/photo-1590069261209-f8e9b8642343?auto=format&fit=crop&w=150&q=80',
      'https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?auto=format&fit=crop&w=150&q=80',
    ];
    final selectedUrl = mockUrls[_itemPhotos[index].length % mockUrls.length];
    
    setState(() {
      _itemPhotos[index].add(selectedUrl);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto berhasil ditambahkan (simulasi).'), duration: Duration(seconds: 1)),
    );
  }

  void _deletePhoto(int itemIndex, int photoIndex) {
    setState(() {
      _itemPhotos[itemIndex].removeAt(photoIndex);
    });
  }

  bool _validateForm() {
    for (int i = 0; i < _pekerjaan.checklistItems.length; i++) {
      final item = _pekerjaan.checklistItems[i];
      final formNumber = i + 1;

      final isChoiceOrBool = item.inputType == InputType.choice;
      final valStr = _itemResults[i].trim();

      if (valStr.isEmpty) {
        if (item.inputType == InputType.number) {
          _showWarningSnackbar('Form $formNumber - ${item.title}: isi nilai aktual terlebih dahulu');
          return false;
        } else if (isChoiceOrBool) {
          _showWarningSnackbar('Form $formNumber - ${item.title}: pilih kesesuaian fisik terlebih dahulu');
          return false;
        } else {
          _showWarningSnackbar('Form $formNumber - ${item.title}: isi hasil input terlebih dahulu');
          return false;
        }
      }

      if (item.inputType == InputType.number) {
        final normalized = valStr.replaceAll(',', '.');
        if (double.tryParse(normalized) == null) {
          _showWarningSnackbar('Form $formNumber - ${item.title}: masukkan angka yang valid');
          return false;
        }
      }

      if (_itemPhotos[i].isEmpty) {
        _showWarningSnackbar('Form $formNumber - ${item.title}: tambahkan dokumentasi foto terlebih dahulu');
        return false;
      }

      final bool isNonIdeal = valStr == 'Tidak' || 
                              valStr == 'Tidak Sesuai' ||
                              (isChoiceOrBool && 
                               !['sesuai', 'rapi', 'kencang', 'ada', 'lengkap', 'ya', 'ok', 'diterima', 'sesuai standar'].contains(valStr.toLowerCase()));

      if (isChoiceOrBool && isNonIdeal && _itemIssues[i].trim().isEmpty) {
        _showWarningSnackbar('Form $formNumber - ${item.title}: isi keterangan masalah terlebih dahulu');
        return false;
      }
    }
    return true;
  }

  void _showWarningSnackbar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.rejectedText,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        backgroundColor: AppColors.rejectedBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _saveAsDraft() {
    showDialog(
      context: context,
      builder: (context) => ConfirmationModal(
        title: 'Simpan sebagai Draft',
        message: 'Apakah Anda yakin ingin menyimpan laporan QC Pekerjaan ini sebagai draft?',
        confirmText: 'Simpan',
        onConfirm: () {
          _persistReport(QCReportStatus.draft);
        },
      ),
    );
  }

  void _submitReport() {
    if (!_validateForm()) return;

    showDialog(
      context: context,
      builder: (context) => ConfirmationModal(
        title: 'Submit Laporan QC',
        message: 'Apakah seluruh data inspeksi pekerjaan konstruksi sudah lengkap dan siap dikirim?',
        confirmText: 'Kirim',
        onConfirm: () {
          _persistReport(QCReportStatus.waiting);
        },
      ),
    );
  }

  void _persistReport(QCReportStatus status) {
    // Generate checklist results
    final List<QCReportChecklistResult> results = [];
    for (int i = 0; i < _pekerjaan.checklistItems.length; i++) {
      final item = _pekerjaan.checklistItems[i];
      results.add(
        QCReportChecklistResult(
          itemId: item.id,
          paramName: item.title,
          standard: item.standard,
          inputType: item.inputType == InputType.number
              ? 'Angka'
              : item.inputType == InputType.choice
                  ? 'Pilihan'
                  : 'Teks',
          unit: item.unit,
          resultValue: _itemResults[i],
          status: _itemStatuses[i],
          issueNote: _itemIssues[i],
          photos: _itemPhotos[i],
        ),
      );
    }

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
      area: _areaController.text.trim().isEmpty ? 'Sektor Utama' : _areaController.text.trim(),
      detailLocation: _locationDetailController.text.trim().isEmpty
          ? 'Titik Pekerjaan Lapangan'
          : _locationDetailController.text.trim(),
      checklistResults: results,
      photos: [],
      staffNote: _staffNoteController.text,
      adminNote: status == QCReportStatus.draft ? null : 'Menunggu review dari Admin.',
    );

    _state.addReport(newReport);

    // Show Success Alert
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          status == QCReportStatus.draft ? 'Berhasil' : 'Laporan berhasil dikirim',
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          status == QCReportStatus.draft
              ? 'Laporan QC Pekerjaan berhasil disimpan sebagai draft.'
              : 'Data QC berhasil dikirim dan akan ditinjau oleh Admin untuk penilaian standar.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/home');
            },
            child: const Text('Kembali ke Home', style: TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/reports');
            },
            child: const Text('Lihat Laporan', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pekerjaan == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Inspeksi Pekerjaan',
                subtitle: _pekerjaan.name,
              ),

              // Card: Detail Laporan Awal
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    AppInput(
                      label: 'Lokasi Site (Aktif)',
                      controller: TextEditingController(text: _state.currentSite.name),
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Area / Zona Kerja',
                      hintText: 'Misal: Area Pondasi Jalur Utama',
                      controller: _areaController,
                      prefixIcon: Icons.map_outlined,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Detail Lokasi / Koordinat',
                      hintText: 'Misal: Depan Ruko Blok C-4 / Tiang No. 12',
                      controller: _locationDetailController,
                      prefixIcon: Icons.my_location_outlined,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Nama Mitra Pelaksana',
                      hintText: 'Misal: CV Terang Abadi Jaya',
                      controller: _mitraController,
                      prefixIcon: Icons.business_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Checklist Section
              const Text(
                'Parameter Checklist Pekerjaan',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              ...List.generate(_pekerjaan.checklistItems.length, (index) {
                final item = _pekerjaan.checklistItems[index];

                // Map InputType to QCInputType
                QCInputType qcInputType;
                switch (item.inputType) {
                  case InputType.number:
                    qcInputType = QCInputType.number;
                    break;
                  case InputType.choice:
                    qcInputType = QCInputType.choice;
                    break;
                  case InputType.text:
                  default:
                    qcInputType = QCInputType.text;
                    break;
                }

                // Map ChecklistStatus to QCResultStatus
                QCResultStatus qcStatus;
                switch (_itemStatuses[index]) {
                  case ChecklistStatus.lulus:
                    qcStatus = QCResultStatus.pass;
                    break;
                  case ChecklistStatus.tidakSesuai:
                    qcStatus = QCResultStatus.fail;
                    break;
                  case ChecklistStatus.perluTindakLanjut:
                    qcStatus = QCResultStatus.needFollowUp;
                    break;
                  case ChecklistStatus.belumDiisi:
                    qcStatus = QCResultStatus.notFilled;
                    break;
                }

                String? warningMessage;
                if (item.inputType == InputType.number && _itemResults[index].trim().isNotEmpty) {
                  final val = _itemResults[index].trim().replaceAll(',', '.');
                  if (double.tryParse(val) == null) {
                    warningMessage = 'Input harus berupa angka';
                  }
                }

                return ChecklistItemCard(
                  itemNumber: index + 1,
                  title: item.title,
                  standardText: item.standard,
                  inputType: qcInputType,
                  unit: item.unit,
                  choices: item.choices,
                  currentStatus: qcStatus,
                  resultValue: _itemResults[index],
                  issueDescription: _itemIssues[index],
                  photos: _itemPhotos[index],
                  warningMessage: warningMessage,
                  isLocked: false,
                  onStatusChanged: (status) {
                    setState(() {
                      ChecklistStatus originalStatus;
                      switch (status) {
                        case QCResultStatus.pass:
                          originalStatus = ChecklistStatus.lulus;
                          break;
                        case QCResultStatus.fail:
                          originalStatus = ChecklistStatus.tidakSesuai;
                          break;
                        case QCResultStatus.needFollowUp:
                          originalStatus = ChecklistStatus.perluTindakLanjut;
                          break;
                        case QCResultStatus.notFilled:
                          originalStatus = ChecklistStatus.belumDiisi;
                          break;
                      }
                      _itemStatuses[index] = originalStatus;
                    });
                  },
                  onResultValueChanged: (val) {
                    setState(() {
                      _itemResults[index] = val;
                      _itemStatuses[index] = _calculateAutoStatusForPekerjaan(item, val);
                    });
                  },
                  onIssueDescriptionChanged: (val) {
                    setState(() {
                      _itemIssues[index] = val;
                    });
                  },
                  onAddPhoto: () => _simulatePhotoUpload(index),
                  onDeletePhoto: (photoIndex) => _deletePhoto(index, photoIndex),
                );
              }),

              // Staff Notes Card
              AppCard(
                padding: const EdgeInsets.all(20),
                child: AppInput(
                  label: 'Catatan QA Staff (Opsional)',
                  hintText: 'Tuliskan catatan tambahan mengenai proses pengerjaan...',
                  controller: _staffNoteController,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 28),

              // Submit & Draft Buttons
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: AppButton(
                      text: 'Simpan Draft',
                      variant: AppButtonVariant.secondary,
                      onPressed: _saveAsDraft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: AppButton(
                      text: 'Submit Laporan',
                      variant: AppButtonVariant.primary,
                      onPressed: _submitReport,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  ChecklistStatus _calculateAutoStatusForPekerjaan(ChecklistItemModel item, String val) {
    final valTrim = val.trim();
    if (valTrim.isEmpty) {
      return ChecklistStatus.belumDiisi;
    }

    if (item.inputType == InputType.number) {
      final parsed = double.tryParse(valTrim.replaceAll(',', '.'));
      if (parsed == null) {
        return ChecklistStatus.belumDiisi; // Will fail validation as invalid
      }
      final lowerTitle = item.title.toLowerCase();
      if (lowerTitle.contains('redaman')) {
        if (parsed >= -24 && parsed <= -15) {
          return ChecklistStatus.lulus;
        }
        return ChecklistStatus.tidakSesuai;
      }
      if (lowerTitle.contains('kedalaman')) {
        if (parsed >= 1.2) {
          return ChecklistStatus.lulus;
        }
        return ChecklistStatus.tidakSesuai;
      }
      if (lowerTitle.contains('pengeringan')) {
        if (parsed >= 24) {
          return ChecklistStatus.lulus;
        }
        return ChecklistStatus.tidakSesuai;
      }
      if (lowerTitle.contains('ketinggian')) {
        if (parsed >= 5) {
          return ChecklistStatus.lulus;
        }
        return ChecklistStatus.tidakSesuai;
      }
      // Fallback for generic numbers
      return ChecklistStatus.lulus;
    } else if (item.inputType == InputType.choice) {
      final lowerVal = valTrim.toLowerCase();
      final passKeywords = [
        'sesuai', 'rapi', 'kencang', 'bersih', 'ada & jelas', 
        'tegak lurus', 'sesuai standar', 'lengkap', 'ya', 'ok'
      ];
      if (passKeywords.contains(lowerVal)) {
        return ChecklistStatus.lulus;
      }
      return ChecklistStatus.tidakSesuai;
    } else {
      // Text inputs
      return ChecklistStatus.lulus;
    }
  }
}
