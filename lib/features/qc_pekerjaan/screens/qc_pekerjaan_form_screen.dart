// Refactored QC Pekerjaan Form using Provider
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../shared/utils/qc_photo_validation.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/qc_draft_protection.dart';
import '../../../shared/services/qc_local_draft_store.dart';
import '../../../shared/models/pekerjaan_model.dart';

class QCPekerjaanFormScreen extends StatefulWidget {
  final PekerjaanModel pekerjaan;
  final String? editReportId;
  final bool isRevision;
  final QCLocalDraftStore draftStore;

  const QCPekerjaanFormScreen({
    super.key,
    required this.pekerjaan,
    this.editReportId,
    this.isRevision = false,
    this.draftStore = const QCLocalDraftStore(),
  });

  @override
  State<QCPekerjaanFormScreen> createState() => _QCPekerjaanFormScreenState();
}

class _QCPekerjaanFormScreenState extends State<QCPekerjaanFormScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<QCDraftProtectionState> _draftProtectionKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QCPekerjaanFormProvider()
        ..init(
          widget.pekerjaan,
          editReportId: widget.editReportId,
          isRevision: widget.isRevision,
        ),
      child: Consumer<QCPekerjaanFormProvider>(
        builder: (context, provider, _) {
          if (!provider.isReady) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return QCDraftProtection(
            key: _draftProtectionKey,
            identity: provider.localDraftIdentity,
            store: widget.draftStore,
            createSnapshot: provider.createLocalDraftSnapshot,
            restoreSnapshot: provider.restoreLocalDraftSnapshot,
            hasProcessingEvidence: provider.hasProcessingPhotos,
            preserveEvidence: provider.preserveLocalDraftEvidence,
            releaseEvidence: provider.releaseLocalDraftEvidence,
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: SafeArea(
                child: SingleChildScrollView(
                  key: const Key('qc_pekerjaan_form_scroll'),
                  controller: _scrollController,
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
                        subtitle: provider.pekerjaan.name,
                      ),
                      _buildProgressSection(provider),
                      const SizedBox(height: 24),
                      if (provider.isInformationStep)
                        _buildDetailCard(provider)
                      else ...[
                        _buildChecklistSection(context, provider),
                        _buildStaffNoteCard(provider),
                      ],
                      const SizedBox(height: 28),
                      _buildActionButtons(context, provider),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressSection(QCPekerjaanFormProvider provider) {
    final stepNumber = provider.currentStep + 1;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Langkah $stepNumber dari ${provider.totalSteps}',
                key: const Key('qc_pekerjaan_step_indicator'),
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                provider.isInformationStep
                    ? 'Data Pekerjaan'
                    : 'Form Pemeriksaan',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            key: const Key('qc_pekerjaan_progress'),
            value: stepNumber / provider.totalSteps,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.primary,
            backgroundColor: AppColors.inactiveBg,
          ),
        ],
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
    final items = p.pekerjaan.checklistItems;
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
          // Map the persisted Staff result independently from Admin review.
          QCResultStatus qcStatus;
          switch (p.itemStatuses[index]) {
            case ChecklistStatus.lulus:
              qcStatus = QCResultStatus.pass;
              break;
            case ChecklistStatus.tidakSesuai:
              qcStatus = QCResultStatus.fail;
              break;
            case ChecklistStatus.perluTindakLanjut:
              qcStatus = QCResultStatus.needFollowUp;
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
                minValue: item.minValue,
                maxValue: item.maxValue,
                choices: item.choices,
                choiceOptions: item.choiceOptions,
                currentStatus: qcStatus,
                resultValue: p.itemResults[index],
                issueDescription: p.itemIssues[index],
                photos: p.itemPhotos[index],
                localPhotos: p.pendingItemPhotos[index],
                localPhotoBytes: p.pendingItemPhotoBytes[index],
                processingPhotos: p.processingItemPhotos[index],
                uploadedPhotoPreviewBytes: p.uploadedPhotoPreviewBytes,
                warningMessage: p.itemWarnings[index],
                isLocked: false,
                onStatusChanged: (status) => p.updateStatus(index, status),
                onResultValueChanged: (val) => p.updateResult(index, val),
                onIssueDescriptionChanged: (val) =>
                    p.updateIssueNote(index, val),
                onAddPhoto: () => _capturePhoto(context, p, index),
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

  Future<void> _capturePhoto(
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

    try {
      final result = await provider.addPhoto(itemIndex);
      if (!context.mounted || result == PhotoAddResult.cancelled) return;
      if (result == PhotoAddResult.limitReached) {
        AppSnackbar.warning(
          context,
          'Maksimal ${QCPekerjaanFormProvider.maxPhotosPerItem} foto untuk setiap checklist.',
        );
      } else if (result == PhotoAddResult.fileTooLarge) {
        AppSnackbar.warning(context, qcPhotoTooLargeMessage);
      } else if (result == PhotoAddResult.addedWithoutLocationServiceDisabled) {
        AppSnackbar.warning(
          context,
          'Foto diambil tanpa bukti lokasi karena layanan lokasi perangkat dinonaktifkan.',
        );
      } else if (result ==
          PhotoAddResult.addedWithoutLocationPermissionDenied) {
        AppSnackbar.warning(
          context,
          'Foto diambil tanpa bukti lokasi karena izin lokasi ditolak.',
        );
      } else if (result ==
          PhotoAddResult.addedWithoutLocationPermissionDeniedForever) {
        AppSnackbar.warning(
          context,
          'Foto diambil tanpa bukti lokasi karena izin lokasi ditolak permanen. Aktifkan izin lokasi di Pengaturan Safari.',
        );
      } else if (result == PhotoAddResult.addedWithoutLocationTimeout) {
        AppSnackbar.warning(
          context,
          'Foto diambil tanpa bukti lokasi karena pencarian lokasi melewati batas waktu 8 detik.',
        );
      } else if (result ==
          PhotoAddResult.addedWithoutLocationPositionUnavailable) {
        AppSnackbar.warning(
          context,
          'Foto diambil tanpa bukti lokasi karena posisi perangkat tidak tersedia.',
        );
      } else if (result == PhotoAddResult.addedWithoutLocationUnexpectedError) {
        AppSnackbar.warning(
          context,
          'Foto diambil tanpa bukti lokasi karena terjadi kesalahan saat membaca lokasi perangkat.',
        );
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

  Widget _buildStaffNoteCard(QCPekerjaanFormProvider p) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: AppInput(
        label: 'Catatan Staff Warehouse (Opsional)',
        hintText: 'Tuliskan catatan tambahan mengenai proses pengerjaan...',
        controller: p.staffNoteController,
        maxLines: 3,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, QCPekerjaanFormProvider p) {
    final navigationDisabled = p.isPersisting;
    final draftButton = AppButton(
      key: const Key('qc_pekerjaan_save_draft_button'),
      text: 'Simpan Draft',
      variant: AppButtonVariant.secondary,
      isLoading: p.isPersisting,
      onPressed: navigationDisabled
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
    );
    if (p.isInformationStep) {
      return Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: AppButton(
                  key: Key('qc_pekerjaan_back_button'),
                  text: 'Kembali',
                  icon: Icons.arrow_back,
                  variant: AppButtonVariant.ghost,
                  onPressed: null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  key: const Key('qc_pekerjaan_next_button'),
                  text: 'Selanjutnya',
                  icon: Icons.arrow_forward,
                  variant: AppButtonVariant.primary,
                  onPressed: navigationDisabled
                      ? null
                      : () {
                          final error = p.goToChecklistStep();
                          if (error != null) {
                            AppSnackbar.error(context, error);
                            return;
                          }
                          _scrollToTop();
                        },
                ),
              ),
            ],
          ),
          if (!p.isRevisionMode) ...[const SizedBox(height: 12), draftButton],
        ],
      );
    }

    final submitButton = AppButton(
      key: const Key('qc_pekerjaan_submit_button'),
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
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('qc_pekerjaan_back_button'),
                text: 'Kembali',
                icon: Icons.arrow_back,
                variant: AppButtonVariant.ghost,
                onPressed: navigationDisabled
                    ? null
                    : () {
                        p.goToInformationStep();
                        _scrollToTop();
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: submitButton),
          ],
        ),
        if (!p.isRevisionMode) ...[const SizedBox(height: 12), draftButton],
      ],
    );
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    });
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
      await _draftProtectionKey.currentState?.completeAndPop();
    } on ReportPersistenceException catch (error) {
      if (!context.mounted) return;
      AppSnackbar.error(context, error.message);
    }
  }
}
