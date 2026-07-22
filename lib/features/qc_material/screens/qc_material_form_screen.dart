// Refactored QC Material Form using Provider
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/checklist_item_card.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/confirmation_modal.dart';
import '../../../shared/widgets/work_location_selector.dart';
import '../../../shared/providers/qc_material_form_provider.dart';
import '../../../shared/utils/qc_photo_validation.dart';
import '../../../shared/widgets/app_snackbar.dart';

import '../../../shared/models/qc_material_template_model.dart';

class QCMaterialFormScreen extends StatelessWidget {
  final String materialId;
  final String? editReportId;
  final bool isRevision;
  final QCMaterialTemplate template;

  const QCMaterialFormScreen({
    super.key,
    required this.materialId,
    this.editReportId,
    this.isRevision = false,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QCMaterialFormProvider()
        ..init(
          materialId,
          editReportId: editReportId,
          isRevision: isRevision,
          template: template,
        ),
      child: Consumer<QCMaterialFormProvider>(
        builder: (context, provider, _) {
          if (!provider.isReady) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          final tpl = provider.template;
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScreenHeader(
                      title: 'Form QC Material',
                      subtitle: '${tpl.name} (${tpl.code})',
                    ),
                    _buildGeneralInfoCard(provider),
                    const SizedBox(height: 20),
                    _buildLocationSection(provider),
                    const SizedBox(height: 24),
                    _buildChecklistSection(context, provider, tpl),
                    _buildStaffNoteCard(provider),
                    const SizedBox(height: 28),
                    _buildActionButtons(context, provider),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGeneralInfoCard(QCMaterialFormProvider p) {
    return AppCard(
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
            controller: p.poNumberController,
            prefixIcon: Icons.receipt_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Tanggal PO',
            hintText: 'YYYY-MM-DD',
            controller: p.poDateController,
            prefixIcon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Nomor DO / Surat Jalan',
            hintText: 'Masukkan nomor Delivery Order',
            controller: p.doNumberController,
            prefixIcon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Nama Mitra Pabrikasi / Vendor',
            hintText: 'Masukkan nama vendor logam/tiang',
            controller: p.vendorNameController,
            prefixIcon: Icons.business_center_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'ID Material',
            hintText: 'Masukkan kode ID material',
            controller: p.materialIdController,
            prefixIcon: Icons.qr_code_scanner_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppInput(
                  label: 'Volume Datang',
                  hintText: 'Contoh: 100',
                  controller: p.arrivalVolumeController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  label: 'Volume Sampling',
                  hintText: 'Contoh: 5',
                  controller: p.samplingVolumeController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Merk Material',
            hintText: 'Masukkan nama merk tiang',
            controller: p.brandNameController,
            prefixIcon: Icons.copyright_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Lokasi Warehouse Penerima',
            hintText: 'Contoh: Gudang Cikarang A',
            controller: p.warehouseLocationController,
            prefixIcon: Icons.store_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Nomor QA/STEL/Versi',
            controller: p.stelVersionController,
            prefixIcon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Masa Berlaku QA',
            hintText: 'YYYY-MM-DD',
            controller: p.qaExpiryDateController,
            prefixIcon: Icons.date_range_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Nomor Sertifikat TKDN',
            controller: p.tkdnNumberController,
            prefixIcon: Icons.shield_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppInput(
                  label: 'Tgl Sertifikat TKDN',
                  controller: p.tkdnCertDateController,
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  label: 'Nilai TKDN (%)',
                  controller: p.tkdnValueController,
                  hintText: 'Contoh: 42.5',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(QCMaterialFormProvider p) {
    return WorkLocationSelector(
      selectedSite: p.selectedSite,
      isCustom: p.isCustomLocation,
      nameController: p.customLocNameController,
      areaController: p.customLocAreaController,
      segmentController: p.customLocSegmentController,
      noteController: p.customLocNoteController,
      onSiteChanged: (site) => p.setSelectedSite(site),
      onModeChanged: (custom) => p.setIsCustomLocation(custom),
    );
  }

  Widget _buildChecklistSection(
    BuildContext context,
    QCMaterialFormProvider p,
    dynamic tpl,
  ) {
    if (tpl.checklistItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Parameter Checklist Mutu',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    size: 48,
                    color: AppColors.textSoft,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Template ini belum memiliki item checklist.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parameter Checklist Mutu',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(tpl.checklistItems.length, (index) {
          final item = tpl.checklistItems[index];
          final answer = p.answers[index];
          final hasValidationError =
              answer.warningMessage != null &&
              answer.warningMessage!.isNotEmpty &&
              answer.warningMessage != 'Wajib diisi';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChecklistItemCard(
                itemNumber: index + 1,
                title: item.label,
                standardText: item.standardText,
                inputType: item.inputType,
                unit: item.unit,
                choiceOptions: item.choiceOptions,
                currentStatus: answer.status,
                resultValue: answer.value,
                issueDescription: answer.issueNote ?? '',
                photos: answer.photoPaths,
                localPhotos: p.localItemPhotos[index],
                localPhotoBytes: p.localItemPhotoBytes[index],
                warningMessage: answer.warningMessage,
                isLocked: hasValidationError,
                onStatusChanged: (status) => p.answers[index].status = status,
                onResultValueChanged: (val) => p.updateAnswer(index, val),
                onIssueDescriptionChanged: (val) =>
                    p.updateIssueNote(index, val),
                onAddPhoto: () => _capturePhoto(context, p, index),
                onDeletePhoto: (pIdx) => p.removePhoto(index, pIdx),
              ),
              if (p.isRevisionMode &&
                  answer.adminNote != null &&
                  answer.adminNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.rejectedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.rejectedText,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.rejectedText,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Catatan Perbaikan Admin (Item ${index + 1}):',
                            style: const TextStyle(
                              color: AppColors.rejectedText,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        answer.adminNote!,
                        style: const TextStyle(
                          color: AppColors.rejectedText,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _capturePhoto(
    BuildContext context,
    QCMaterialFormProvider provider,
    int itemIndex,
  ) async {
    if (provider.isPersisting) return;

    try {
      final result = await provider.addPhoto(itemIndex);
      if (!context.mounted || result == QCMaterialPhotoAddResult.cancelled) {
        return;
      }
      if (result == QCMaterialPhotoAddResult.fileTooLarge) {
        AppSnackbar.warning(context, qcPhotoTooLargeMessage);
      }
    } on PlatformException {
      if (!context.mounted) return;
      AppSnackbar.error(
        context,
        'Tidak dapat mengakses kamera. Periksa izin aplikasi lalu coba lagi.',
      );
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.error(
        context,
        'Foto tidak dapat diambil. Silakan coba lagi.',
      );
    }
  }

  Widget _buildStaffNoteCard(QCMaterialFormProvider p) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: AppInput(
        label: 'Catatan QA Staff (Opsional)',
        hintText:
            'Tuliskan catatan tambahan mengenai hasil pengujian material...',
        controller: p.staffNoteController,
        maxLines: 3,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, QCMaterialFormProvider p) {
    return Row(
      children: [
        if (!p.isRevisionMode) ...[
          Expanded(
            flex: 4,
            child: AppButton(
              text: 'Simpan Form',
              variant: AppButtonVariant.secondary,
              isLoading: p.isPersisting,
              onPressed: () async {
                if (!p.hasAnyDraftContent) {
                  AppSnackbar.warning(
                    context,
                    'Isi minimal satu data pemeriksaan sebelum menyimpan draft.',
                  );
                  return;
                }
                try {
                  await p.persistReport(QCReportStatus.DRAFT);
                  if (!context.mounted) return;
                  AppSnackbar.success(context, 'Draft berhasil disimpan');
                  context.pop();
                } on QCMaterialPersistenceException catch (error) {
                  if (!context.mounted) return;
                  AppSnackbar.error(context, error.message);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 6,
          child: AppButton(
            text: p.isRevisionMode ? 'Kirim Ulang' : 'Kirim Laporan',
            variant: AppButtonVariant.primary,
            isLoading: p.isPersisting,
            onPressed: () {
              final locError = p.validateLocation();
              if (locError != null) {
                AppSnackbar.error(context, locError);
                return;
              }
              final error = p.validateForm();
              if (error != null) {
                AppSnackbar.error(context, error);
                return;
              }
              showDialog(
                context: context,
                builder: (c) => ConfirmationModal(
                  title: p.isRevisionMode
                      ? 'Kirim Ulang Laporan'
                      : 'Kirim Laporan QC',
                  message: p.isRevisionMode
                      ? 'Apakah perbaikan data pengujian sudah benar dan siap dikirim ulang?'
                      : 'Apakah seluruh data pengujian sudah benar dan siap dikirim?',
                  confirmText: p.isRevisionMode ? 'Kirim Ulang' : 'Kirim',
                  onConfirm: () async {
                    Navigator.pop(c);
                    try {
                      await p.persistReport(QCReportStatus.SUBMITTED);
                      if (!context.mounted) return;
                      context.pop();
                    } on QCMaterialPersistenceException catch (error) {
                      if (!context.mounted) return;
                      AppSnackbar.error(context, error.message);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
