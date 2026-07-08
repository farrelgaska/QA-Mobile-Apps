import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_qc_material_templates.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../core/utils/qc_validation_helper.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/qc_report_model.dart';
import '../../../shared/models/qc_checklist_answer_model.dart';
import '../../../shared/models/qc_material_template_model.dart';
import '../../../shared/models/work_location_model.dart';
import '../../../shared/models/site_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/checklist_item_card.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/confirmation_modal.dart';
import '../../../shared/widgets/work_location_selector.dart';
import '../../../shared/widgets/qc_conclusion_box.dart';

class QCMaterialFormScreen extends StatefulWidget {
  final String materialId;

  const QCMaterialFormScreen({
    Key? key,
    required this.materialId,
  }) : super(key: key);

  @override
  State<QCMaterialFormScreen> createState() => _QCMaterialFormScreenState();
}

class _QCMaterialFormScreenState extends State<QCMaterialFormScreen> {
  final _state = DummyState();
  
  // Dynamic template model
  late QCMaterialTemplate _template;
  bool _isInit = false;

  // General Info controllers
  final _poNumberController = TextEditingController();
  final _poDateController = TextEditingController();
  final _doNumberController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _materialIdController = TextEditingController();
  final _arrivalVolumeController = TextEditingController();
  final _samplingVolumeController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _warehouseLocationController = TextEditingController();
  final _stelVersionController = TextEditingController();
  final _qaExpiryDateController = TextEditingController();
  final _tkdnNumberController = TextEditingController();
  final _tkdnCertDateController = TextEditingController();
  final _tkdnValueController = TextEditingController();

  final _staffNoteController = TextEditingController();

  // Location selector state
  late SiteModel _selectedSite;
  bool _isCustomLocation = false;
  final _customLocNameController = TextEditingController();
  final _customLocAreaController = TextEditingController();
  final _customLocSegmentController = TextEditingController();
  final _customLocNoteController = TextEditingController();

  // Answers list
  final List<QCChecklistAnswer> _answers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      // Find template
      _template = dummyQCMaterialTemplates.firstWhere(
        (t) => t.id == widget.materialId,
        orElse: () => dummyQCMaterialTemplates[0],
      );

      // Prepopulate some template metadata
      _materialIdController.text = _template.id;
      _stelVersionController.text = _template.code == 'TA-FR-048-010-01'
          ? 'STEL-L-017-2024 Ver.2'
          : 'STEL-QA-MYTA-2026';
      _tkdnNumberController.text = 'TKDN-${_template.code}-2026';
      _poDateController.text = '2026-07-01';
      _qaExpiryDateController.text = '2028-12-31';
      _tkdnCertDateController.text = '2026-01-15';

      _selectedSite = _state.currentSite;

      // Initialize answers list
      for (var item in _template.checklistItems) {
        _answers.add(
          QCChecklistAnswer(
            itemId: item.id,
            value: '',
            status: QCResultStatus.notFilled,
            photoPaths: [],
            paramName: item.label,
            standardText: item.standardText,
            unit: item.unit,
          ),
        );
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    _poNumberController.dispose();
    _poDateController.dispose();
    _doNumberController.dispose();
    _vendorNameController.dispose();
    _materialIdController.dispose();
    _arrivalVolumeController.dispose();
    _samplingVolumeController.dispose();
    _brandNameController.dispose();
    _warehouseLocationController.dispose();
    _stelVersionController.dispose();
    _qaExpiryDateController.dispose();
    _tkdnNumberController.dispose();
    _tkdnCertDateController.dispose();
    _tkdnValueController.dispose();
    _staffNoteController.dispose();
    _customLocNameController.dispose();
    _customLocAreaController.dispose();
    _customLocSegmentController.dispose();
    _customLocNoteController.dispose();
    super.dispose();
  }

  void _onAnswerValueChanged(int index, String value) {
    final item = _template.checklistItems[index];
    setState(() {
      _answers[index].value = value;

      // Auto validate numeric/rule values
      final valRes = QCValidationHelper.validateChecklistAnswer(
        item: item,
        value: value,
      );

      _answers[index].warningMessage = valRes.warningMessage;

      if (valRes.status == QCResultStatus.fail) {
        _answers[index].status = QCResultStatus.fail;
      } else if (valRes.status == QCResultStatus.pass) {
        _answers[index].status = QCResultStatus.pass;
      } else {
        _answers[index].status = QCResultStatus.notFilled;
      }
    });
  }

  void _simulatePhotoUpload(int index) {
    final mockUrls = [
      'https://images.unsplash.com/photo-1590066070792-4aa7d9bf5df7?auto=format&fit=crop&w=150&q=80',
      'https://images.unsplash.com/photo-1581094288338-2314dddb7ecc?auto=format&fit=crop&w=150&q=80',
    ];
    final url = mockUrls[_answers[index].photoPaths.length % mockUrls.length];
    setState(() {
      _answers[index].photoPaths.add(url);
    });
    
    // Auto revalidate to clear error of photo required
    _revalidateItem(index);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto bukti berhasil diunggah.'), duration: Duration(seconds: 1)),
    );
  }

  void _deletePhoto(int itemIndex, int photoIndex) {
    setState(() {
      _answers[itemIndex].photoPaths.removeAt(photoIndex);
    });
    _revalidateItem(itemIndex);
  }

  void _revalidateItem(int index) {
    final item = _template.checklistItems[index];
    final value = _answers[index].value;
    final valRes = QCValidationHelper.validateChecklistAnswer(item: item, value: value);
    setState(() {
      _answers[index].warningMessage = valRes.warningMessage;
    });
  }

  String _calculateAutoConclusion() {
    final result = QCValidationHelper.validateBeforeSubmit(
      items: _template.checklistItems,
      answers: _answers,
    );
    return result.finalConclusion;
  }

  void _saveAsDraft() {
    showDialog(
      context: context,
      builder: (context) => ConfirmationModal(
        title: 'Simpan sebagai Draft',
        message: 'Apakah Anda yakin ingin menyimpan kemajuan form ini sebagai draft?',
        confirmText: 'Simpan',
        onConfirm: () {
          _persistReport(QCReportStatus.draft);
        },
      ),
    );
  }

  String? _validateFormFirstError() {
    if (_poNumberController.text.trim().isEmpty) {
      return 'Isi nomor PO terlebih dahulu';
    }
    if (_doNumberController.text.trim().isEmpty) {
      return 'Isi nomor DO terlebih dahulu';
    }
    if (_vendorNameController.text.trim().isEmpty) {
      return 'Isi nama vendor terlebih dahulu';
    }
    if (_arrivalVolumeController.text.trim().isEmpty) {
      return 'Isi volume datang terlebih dahulu';
    }
    if (_samplingVolumeController.text.trim().isEmpty) {
      return 'Isi volume sampling terlebih dahulu';
    }
    if (_brandNameController.text.trim().isEmpty) {
      return 'Isi merk material terlebih dahulu';
    }
    if (_warehouseLocationController.text.trim().isEmpty) {
      return 'Isi lokasi warehouse terlebih dahulu';
    }
    if (_isCustomLocation) {
      if (_customLocNameController.text.trim().isEmpty) {
        return 'Isi nama lokasi kustom terlebih dahulu';
      }
      if (_customLocAreaController.text.trim().isEmpty) {
        return 'Isi area/zona lokasi kustom terlebih dahulu';
      }
      if (_customLocSegmentController.text.trim().isEmpty) {
        return 'Isi titik/segmen lokasi kustom terlebih dahulu';
      }
    }

    for (int i = 0; i < _template.checklistItems.length; i++) {
      final item = _template.checklistItems[i];
      final answer = _answers[i];
      final formNumber = i + 1;

      final isChoiceOrBool = item.inputType == QCInputType.choice || item.inputType == QCInputType.booleanCheck;

      if (answer.value.toString().trim().isEmpty) {
        if (isChoiceOrBool) {
          return 'Form $formNumber - ${item.label}: pilih kesesuaian fisik terlebih dahulu';
        } else {
          return 'Form $formNumber - ${item.label}: isi hasil input terlebih dahulu';
        }
      }
      if (answer.status == QCResultStatus.notFilled) {
        if (isChoiceOrBool) {
          return 'Form $formNumber - ${item.label}: pilih kesesuaian fisik terlebih dahulu';
        } else {
          return 'Form $formNumber - ${item.label}: isi hasil input terlebih dahulu';
        }
      }
      if (answer.photoPaths.isEmpty) {
        return 'Form $formNumber - ${item.label}: tambahkan dokumentasi foto terlebih dahulu';
      }
      if ((answer.status == QCResultStatus.fail || answer.status == QCResultStatus.needFollowUp) &&
          (answer.issueNote == null || answer.issueNote!.trim().isEmpty)) {
        return 'Form $formNumber - ${item.label}: isi keterangan masalah terlebih dahulu';
      }
    }

    return null;
  }

  void _submitReport() {
    final firstError = _validateFormFirstError();
    if (firstError != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firstError,
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
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ConfirmationModal(
        title: 'Kirim Laporan QC',
        message: 'Apakah seluruh data pengujian sudah benar dan siap dikirim?',
        confirmText: 'Kirim',
        onConfirm: () {
          final validationResult = QCValidationHelper.validateBeforeSubmit(
            items: _template.checklistItems,
            answers: _answers,
          );
          final isDiterima = validationResult.finalConclusion == 'Diterima';
          _persistReport(
            isDiterima ? QCReportStatus.approved : QCReportStatus.rejected,
            conclusion: validationResult.finalConclusion,
          );
        },
      ),
    );
  }

  void _persistReport(QCReportStatus status, {String? conclusion}) {
    // Generate location model
    final workLoc = WorkLocation(
      siteName: _isCustomLocation ? _customLocNameController.text : _selectedSite.name,
      area: _isCustomLocation ? _customLocAreaController.text : 'Area Site Utama',
      segment: _isCustomLocation ? _customLocSegmentController.text : 'Segmen Default',
      note: _isCustomLocation ? _customLocNoteController.text : '',
      isCustom: _isCustomLocation,
    );

    // General Info Map
    final Map<String, String> genInfo = {
      'poNumber': _poNumberController.text.trim(),
      'poDate': _poDateController.text.trim(),
      'doNumber': _doNumberController.text.trim(),
      'vendorName': _vendorNameController.text.trim(),
      'materialId': _materialIdController.text.trim(),
      'arrivalVolume': _arrivalVolumeController.text.trim(),
      'samplingVolume': _samplingVolumeController.text.trim(),
      'brandName': _brandNameController.text.trim(),
      'warehouseLocation': _warehouseLocationController.text.trim(),
      'stelVersion': _stelVersionController.text.trim(),
      'qaExpiryDate': _qaExpiryDateController.text.trim(),
      'tkdnNumber': _tkdnNumberController.text.trim(),
      'tkdnCertDate': _tkdnCertDateController.text.trim(),
      'tkdnValue': _tkdnValueController.text.trim(),
    };

    final newReport = QCReportModel(
      id: 'QC-MAT-${DateTime.now().year}-${1000 + _state.reports.length}',
      title: _template.name,
      type: QCType.material,
      status: status,
      checkedByName: _state.currentUser.name,
      checkedByNik: _state.currentUser.nik,
      date: DateTime.now(),
      siteId: _isCustomLocation ? 'custom-site' : _selectedSite.id,
      siteName: workLoc.siteName,
      area: workLoc.area ?? '',
      detailLocation: workLoc.segment ?? '',
      checklistAnswers: List.from(_answers),
      photos: [],
      staffNote: _staffNoteController.text,
      adminNote: status == QCReportStatus.draft ? null : 'Menunggu review dari Admin.',
      formCode: _template.code,
      workLocation: workLoc,
      generalInfo: genInfo,
      finalConclusion: conclusion ?? _calculateAutoConclusion(),
    );

    _state.addReport(newReport);

    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Berhasil', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: Text(
          status == QCReportStatus.draft
              ? 'Laporan QC Material berhasil disimpan sebagai draft.'
              : 'Laporan QC Material berhasil dikirim ke Admin.',
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
    if (!_isInit) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final conclusion = _calculateAutoConclusion();

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
                title: 'Form QC Material',
                subtitle: '${_template.name} (${_template.code})',
              ),

              // 1. Section: Informasi Umum PO/DO
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Umum Pengadaan',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Nomor PO',
                      hintText: 'Masukkan nomor Purchase Order',
                      controller: _poNumberController,
                      prefixIcon: Icons.receipt_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Tanggal PO',
                      hintText: 'YYYY-MM-DD',
                      controller: _poDateController,
                      prefixIcon: Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Nomor DO / Surat Jalan',
                      hintText: 'Masukkan nomor Delivery Order',
                      controller: _doNumberController,
                      prefixIcon: Icons.local_shipping_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Nama Mitra Pabrikasi / Vendor',
                      hintText: 'Masukkan nama vendor logam/tiang',
                      controller: _vendorNameController,
                      prefixIcon: Icons.business_center_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'ID Material',
                      hintText: 'Masukkan kode ID material',
                      controller: _materialIdController,
                      prefixIcon: Icons.qr_code_scanner_outlined,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            label: 'Volume Datang',
                            hintText: 'Contoh: 100',
                            controller: _arrivalVolumeController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppInput(
                            label: 'Volume Sampling',
                            hintText: 'Contoh: 5',
                            controller: _samplingVolumeController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Merk Material',
                      hintText: 'Masukkan nama merk tiang',
                      controller: _brandNameController,
                      prefixIcon: Icons.copyright_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Lokasi Warehouse Penerima',
                      hintText: 'Contoh: Gudang Cikarang A',
                      controller: _warehouseLocationController,
                      prefixIcon: Icons.store_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Nomor QA/STEL/Versi',
                      controller: _stelVersionController,
                      prefixIcon: Icons.verified_user_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Masa Berlaku QA',
                      hintText: 'YYYY-MM-DD',
                      controller: _qaExpiryDateController,
                      prefixIcon: Icons.date_range_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      label: 'Nomor Sertifikat TKDN',
                      controller: _tkdnNumberController,
                      prefixIcon: Icons.shield_outlined,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            label: 'Tgl Sertifikat TKDN',
                            controller: _tkdnCertDateController,
                            hintText: 'YYYY-MM-DD',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppInput(
                            label: 'Nilai TKDN (%)',
                            controller: _tkdnValueController,
                            hintText: 'Contoh: 42.5',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Section: Lokasi Kerja (Dropdown + Custom)
              WorkLocationSelector(
                selectedSite: _selectedSite,
                isCustom: _isCustomLocation,
                nameController: _customLocNameController,
                areaController: _customLocAreaController,
                segmentController: _customLocSegmentController,
                noteController: _customLocNoteController,
                onSiteChanged: (SiteModel site) {
                  setState(() {
                    _selectedSite = site;
                  });
                },
                onModeChanged: (bool customMode) {
                  setState(() {
                    _isCustomLocation = customMode;
                  });
                },
              ),
              const SizedBox(height: 24),

              // 3. Section: Checklist Pemeriksaan Dinamis
              const Text(
                'Parameter Checklist Mutu',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              
              ...List.generate(_template.checklistItems.length, (index) {
                final item = _template.checklistItems[index];
                final answer = _answers[index];

                // Lock status Lulus if numeric check fails
                final hasValidationError = answer.warningMessage != null && 
                    answer.warningMessage!.isNotEmpty && 
                    answer.warningMessage != 'Wajib diisi';

                return ChecklistItemCard(
                  itemNumber: index + 1,
                  title: item.label,
                  standardText: item.standardText,
                  inputType: item.inputType,
                  unit: item.unit,
                  choices: item.choices,
                  currentStatus: answer.status,
                  resultValue: answer.value.toString(),
                  issueDescription: answer.issueNote ?? '',
                  photos: answer.photoPaths,
                  warningMessage: answer.warningMessage,
                  isLocked: hasValidationError,
                  onStatusChanged: (status) {
                    setState(() {
                      _answers[index].status = status;
                    });
                  },
                  onResultValueChanged: (val) => _onAnswerValueChanged(index, val),
                  onIssueDescriptionChanged: (val) {
                    setState(() {
                      _answers[index].issueNote = val;
                    });
                  },
                  onAddPhoto: () => _simulatePhotoUpload(index),
                  onDeletePhoto: (photoIndex) => _deletePhoto(index, photoIndex),
                );
              }),

              // 4. Section: Kesimpulan Otomatis
              const Text(
                'Evaluasi Mutu Otomatis',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              QCConclusionBox(conclusionState: conclusion),
              const SizedBox(height: 20),

              // 5. Staff Note Card
              AppCard(
                padding: const EdgeInsets.all(20),
                child: AppInput(
                  label: 'Catatan QA Staff (Opsional)',
                  hintText: 'Tuliskan catatan tambahan mengenai hasil pengujian material...',
                  controller: _staffNoteController,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 28),

              // Buttons Action
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
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
