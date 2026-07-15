// Refactored QC Pekerjaan Form using Provider
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/checklist_item_card.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/confirmation_modal.dart';
import '../../../shared/providers/qc_pekerjaan_form_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';

class QCPekerjaanFormScreen extends StatelessWidget {
  final String pekerjaanId;
  final String? editReportId;
  final bool isRevision;

  const QCPekerjaanFormScreen({
    super.key,
    required this.pekerjaanId,
    this.editReportId,
    this.isRevision = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QCPekerjaanFormProvider()
        ..init(pekerjaanId, editReportId: editReportId, isRevision: isRevision),
      child: Consumer<QCPekerjaanFormProvider>(
        builder: (context, provider, _) {
          if (!provider.isReady) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
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
                      title: 'Inspeksi Pekerjaan',
                      subtitle: provider.pekerjaan.name as String,
                    ),
                    _buildDetailCard(provider),
                    const SizedBox(height: 24),
                    _buildChecklistSection(context, provider),
                    _buildStaffNoteCard(provider),
                    const SizedBox(height: 28),
                    _buildActionButtons(context, provider),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(QCPekerjaanFormProvider p) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AppInput(
            label: 'Lokasi Site (Aktif)',
            controller: TextEditingController(text: p.state.currentSite.name),
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 16),
          AppInput(
            label: 'Area / Zona Kerja',
            hintText: 'Misal: Area Pondasi Jalur Utama',
            controller: p.areaController,
            prefixIcon: Icons.map_outlined,
          ),
          const SizedBox(height: 16),
          AppInput(
            label: 'Detail Lokasi / Koordinat',
            hintText: 'Misal: Depan Ruko Blok C-4 / Tiang No. 12',
            controller: p.locationDetailController,
            prefixIcon: Icons.my_location_outlined,
          ),
          const SizedBox(height: 16),
          AppInput(
            label: 'Nama Mitra Pelaksana',
            hintText: 'Misal: CV Terang Abadi Jaya',
            controller: p.mitraController,
            prefixIcon: Icons.business_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection(
    BuildContext context,
    QCPekerjaanFormProvider p,
  ) {
    final items = p.pekerjaan.checklistItems as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parameter Checklist Pekerjaan',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(items.length, (index) {
          final item = items[index];
          // Map InputType → QCInputType
          QCInputType qcInputType;
          switch (item.inputType) {
            case InputType.number:
              qcInputType = QCInputType.number;
              break;
            case InputType.choice:
              qcInputType = QCInputType.choice;
              break;
            default:
              qcInputType = QCInputType.text;
          }
          // Map ChecklistStatus → QCResultStatus (staff-side: neutral states only, no pass/fail)
          QCResultStatus qcStatus;
          switch (p.itemStatuses[index]) {
            case ChecklistStatus.inputTidakValid:
              qcStatus = QCResultStatus
                  .notFilled; // show as not filled to allow correction
              break;
            case ChecklistStatus.perluDilengkapi:
              qcStatus =
                  QCResultStatus.notFilled; // incomplete, show as not filled
              break;
            case ChecklistStatus.sudahDiisi:
              qcStatus = QCResultStatus
                  .notFilled; // filled but Admin evaluates PASS/FAIL
              break;
            default:
              qcStatus = QCResultStatus.notFilled;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChecklistItemCard(
                itemNumber: index + 1,
                title: item.title,
                standardText: item.standard,
                inputType: qcInputType,
                unit: item.unit,
                choices: item.choices,
                currentStatus: qcStatus,
                resultValue: p.itemResults[index],
                issueDescription: p.itemIssues[index],
                photos: p.itemPhotos[index],
                localPhotos: p.pendingItemPhotos[index],
                warningMessage: p.itemWarnings[index],
                isLocked: false,
                onStatusChanged: (status) => p.updateStatus(index, status),
                onResultValueChanged: (val) => p.updateResult(index, val),
                onIssueDescriptionChanged: (val) =>
                    p.updateIssueNote(index, val),
                onAddPhoto: () => _showPhotoSourceOptions(context, p, index),
                onDeletePhoto: (pIdx) => p.removePhoto(index, pIdx),
              ),
              if (p.isRevisionMode &&
                  p.itemAdminNotes[index] != null &&
                  p.itemAdminNotes[index]!.isNotEmpty) ...[
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
                        p.itemAdminNotes[index]!,
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

  Future<void> _showPhotoSourceOptions(
    BuildContext context,
    QCPekerjaanFormProvider provider,
    int itemIndex,
  ) async {
    if (provider.isPersisting) return;
    if (provider.photoCount(itemIndex) >=
        QCPekerjaanFormProvider.maxPhotosPerItem) {
      AppSnackbar.warning(
        context,
        'Maksimal ${QCPekerjaanFormProvider.maxPhotosPerItem} foto untuk setiap checklist.',
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null || !context.mounted) return;

    try {
      final result = await provider.addPhoto(itemIndex, source);
      if (!context.mounted || result == PhotoAddResult.cancelled) return;
      if (result == PhotoAddResult.limitReached) {
        AppSnackbar.warning(
          context,
          'Maksimal ${QCPekerjaanFormProvider.maxPhotosPerItem} foto untuk setiap checklist.',
        );
      }
    } on PlatformException {
      if (!context.mounted) return;
      final sourceName = source == ImageSource.camera ? 'kamera' : 'galeri';
      AppSnackbar.error(
        context,
        'Tidak dapat mengakses $sourceName. Periksa izin aplikasi lalu coba lagi.',
      );
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.error(
        context,
        'Foto tidak dapat dipilih. Silakan coba lagi.',
      );
    }
  }

  Widget _buildStaffNoteCard(QCPekerjaanFormProvider p) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: AppInput(
        label: 'Catatan QA Staff (Opsional)',
        hintText: 'Tuliskan catatan tambahan mengenai proses pengerjaan...',
        controller: p.staffNoteController,
        maxLines: 3,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, QCPekerjaanFormProvider p) {
    return Row(
      children: [
        if (!p.isRevisionMode) ...[
          Expanded(
            flex: 4,
            child: AppButton(
              text: 'Simpan Draft',
              variant: AppButtonVariant.secondary,
              isLoading: p.isPersisting,
              onPressed: p.isPersisting
                  ? null
                  : () async {
                      if (!p.hasAnyDraftContent) {
                        AppSnackbar.warning(
                          context,
                          'Isi minimal satu data pemeriksaan sebelum menyimpan draft.',
                        );
                        return;
                      }
                      await _persistAndExit(
                        context,
                        p,
                        QCReportStatus.DRAFT,
                        'Draft berhasil disimpan',
                      );
                    },
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 6,
          child: AppButton(
            text: p.isRevisionMode ? 'Kirim Ulang' : 'Submit Laporan',
            variant: AppButtonVariant.primary,
            isLoading: p.isPersisting,
            onPressed: p.isPersisting
                ? null
                : () {
                    final err = p.validateForm();
                    if (err != null) {
                      AppSnackbar.error(context, err);
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (c) => ConfirmationModal(
                        title: p.isRevisionMode
                            ? 'Kirim Ulang Laporan'
                            : 'Submit Laporan QC',
                        message: p.isRevisionMode
                            ? 'Apakah perbaikan data inspeksi sudah lengkap dan siap dikirim ulang?'
                            : 'Apakah seluruh data inspeksi pekerjaan konstruksi sudah lengkap dan siap dikirim?',
                        confirmText: p.isRevisionMode ? 'Kirim Ulang' : 'Kirim',
                        onConfirm: () async {
                          if (p.isPersisting) return;
                          Navigator.pop(c);
                          await _persistAndExit(
                            context,
                            p,
                            QCReportStatus.SUBMITTED,
                            p.isRevisionMode
                                ? 'Laporan berhasil dikirim ulang'
                                : 'Laporan berhasil dikirim',
                          );
                        },
                      ),
                    );
                  },
          ),
        ),
      ],
    );
  }

  Future<void> _persistAndExit(
    BuildContext context,
    QCPekerjaanFormProvider provider,
    QCReportStatus status,
    String successMessage,
  ) async {
    try {
      await provider.persistReport(status);
      if (!context.mounted) return;
      AppSnackbar.success(context, successMessage);
      context.pop();
    } on ReportPersistenceException catch (error) {
      if (!context.mounted) return;
      AppSnackbar.error(context, error.message);
    }
  }
}
