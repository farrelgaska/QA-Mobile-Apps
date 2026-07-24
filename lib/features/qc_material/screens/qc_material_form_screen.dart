// Refactored QC Material Form using Provider
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/qc_material_evaluation_model.dart';
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

class QCMaterialFormScreen extends StatefulWidget {
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
  State<QCMaterialFormScreen> createState() => _QCMaterialFormScreenState();
}

class _QCMaterialFormScreenState extends State<QCMaterialFormScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _reviewHighlightTimer;
  bool _navigationEligibilityInitialized = false;
  bool _eligibilityAtLastNavigation = false;
  bool _hasHighlightedReviewEligibility = false;
  bool _highlightReviewWarning = false;

  @override
  void dispose() {
    _reviewHighlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QCMaterialFormProvider()
        ..init(
          widget.materialId,
          editReportId: widget.editReportId,
          isRevision: widget.isRevision,
          template: widget.template,
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
          if (!_navigationEligibilityInitialized) {
            _navigationEligibilityInitialized = true;
            _eligibilityAtLastNavigation = provider.isSamplingWarningActive;
            _hasHighlightedReviewEligibility = provider.isSamplingWarningActive;
          }
          final generalFieldContexts = <QCMaterialGeneralField, BuildContext>{};
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: SingleChildScrollView(
                key: const Key('qc_material_form_scroll'),
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
                      title: 'Form QC Material',
                      subtitle: '${tpl.name} (${tpl.code})',
                    ),
                    _buildProgressSection(provider),
                    if (provider.isSamplingWarningActive) ...[
                      const SizedBox(height: 16),
                      _buildReviewRequestCard(context, provider),
                    ],
                    const SizedBox(height: 24),
                    if (provider.isGeneralStep) ...[
                      _buildGeneralInfoCard(provider, generalFieldContexts),
                      const SizedBox(height: 20),
                      _buildLocationSection(provider, generalFieldContexts),
                      const SizedBox(height: 20),
                      _buildStaffNoteCard(provider),
                    ] else ...[
                      _buildSampleHeading(provider),
                      const SizedBox(height: 16),
                      _buildChecklistSection(context, provider, tpl),
                      _buildSampleNoteCard(provider),
                    ],
                    const SizedBox(height: 28),
                    _buildActionButtons(
                      context,
                      provider,
                      generalFieldContexts,
                    ),
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

  Widget _buildProgressSection(QCMaterialFormProvider provider) {
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
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                provider.isGeneralStep
                    ? 'Informasi Pengadaan'
                    : 'Sampel ${provider.currentSample!.sampleNumber}',
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
            key: const Key('qc_material_progress'),
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

  Widget _buildSampleHeading(QCMaterialFormProvider provider) {
    final status = provider.currentSampleEvaluationStatus;
    final isOutOfStandard = status == QCSampleEvaluationStatus.outOfStandard;
    final isWithinStandard = status == QCSampleEvaluationStatus.withinStandard;
    final statusColor = isOutOfStandard
        ? AppColors.rejectedText
        : isWithinStandard
        ? AppColors.approvedText
        : AppColors.inactiveText;
    final statusBackground = isOutOfStandard
        ? AppColors.rejectedBg
        : isWithinStandard
        ? AppColors.approvedBg
        : AppColors.inactiveBg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sampel ${provider.currentSample!.sampleNumber} dari ${provider.sampleCount}',
          key: const Key('qc_material_sample_indicator'),
          style: const TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Isi checklist hanya untuk sampel ini.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          key: const Key('qc_material_current_sample_status'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: statusBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOutOfStandard
                    ? Icons.error_outline
                    : isWithinStandard
                    ? Icons.check_circle_outline
                    : Icons.schedule_outlined,
                color: statusColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Status Sampel: ${status.displayLabel}',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRequestCard(
    BuildContext context,
    QCMaterialFormProvider provider,
  ) {
    final decision = provider.samplingDecision;
    final card = AppCard(
      key: const Key('qc_material_review_request_card'),
      color: AppColors.rejectedBg,
      border: Border.all(color: AppColors.rejectedText),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.rejectedText,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  decision == null
                      ? 'Material terindikasi tidak memenuhi standar.'
                      : decision.type == QCMaterialSamplingDecisionType.stop
                      ? 'Pemeriksaan dihentikan.'
                      : 'Pemeriksaan dilanjutkan.',
                  style: const TextStyle(
                    color: AppColors.rejectedText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Material dapat dikembalikan kepada vendor dan laporan '
            'memerlukan revisi. Pemeriksaan tidak dihentikan secara otomatis.',
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sampel tidak sesuai: '
            '${decision?.failedSampleNumbers.join(', ') ?? provider.failedCompletedSamples.map((sample) => sample.sampleNumber).join(', ')}.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (decision != null) ...[
            const SizedBox(height: 6),
            Text(
              'Keputusan ${decision.type.apiValue} dicatat pada '
              '${_reviewTimestamp(decision.decidedAt)}.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (decision.stopReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Alasan penghentian: ${decision.stopReason}',
                style: const TextStyle(color: AppColors.textMain, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
    return AnimatedScale(
      scale: _highlightReviewWarning ? 1.015 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: KeyedSubtree(
        key: Key(
          _highlightReviewWarning
              ? 'qc_material_review_warning_highlight'
              : 'qc_material_review_warning_idle',
        ),
        child: card,
      ),
    );
  }

  String _reviewTimestamp(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}-${twoDigits(local.month)}-${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  Widget _buildGeneralInfoCard(
    QCMaterialFormProvider p,
    Map<QCMaterialGeneralField, BuildContext> fieldContexts,
  ) {
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
          _buildGeneralInput(
            field: QCMaterialGeneralField.poNumber,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Nomor PO',
            hintText: 'Masukkan nomor Purchase Order',
            controller: p.poNumberController,
            prefixIcon: Icons.receipt_outlined,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.poDate,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Tanggal PO',
            hintText: 'YYYY-MM-DD',
            controller: p.poDateController,
            prefixIcon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.doNumber,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Nomor DO / Surat Jalan',
            hintText: 'Masukkan nomor Delivery Order',
            controller: p.doNumberController,
            prefixIcon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.vendorName,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Nama Mitra Pabrikasi / Vendor',
            hintText: 'Masukkan nama vendor logam/tiang',
            controller: p.vendorNameController,
            prefixIcon: Icons.business_center_outlined,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.materialId,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'ID Material',
            hintText: 'Masukkan kode ID material',
            controller: p.materialIdController,
            prefixIcon: Icons.qr_code_scanner_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGeneralInput(
                  field: QCMaterialGeneralField.arrivalVolume,
                  provider: p,
                  fieldContexts: fieldContexts,
                  label: 'Volume Datang',
                  hintText: 'Contoh: 100',
                  controller: p.arrivalVolumeController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGeneralInput(
                  field: QCMaterialGeneralField.samplingVolume,
                  provider: p,
                  fieldContexts: fieldContexts,
                  label: 'Volume Sampling',
                  hintText: 'Contoh: 5',
                  controller: p.samplingVolumeController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.sampleCount,
            provider: p,
            fieldContexts: fieldContexts,
            key: const Key('qc_material_sample_count'),
            label: 'Jumlah Sampel',
            hintText: 'Contoh: 5',
            controller: p.sampleCountController,
            keyboardType: TextInputType.number,
            helperText: 'Menentukan jumlah langkah pemeriksaan sampel.',
            prefixIcon: Icons.format_list_numbered,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.brandName,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Merk Material',
            hintText: 'Masukkan nama merk tiang',
            controller: p.brandNameController,
            prefixIcon: Icons.copyright_outlined,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.warehouseLocation,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Lokasi Warehouse Penerima',
            hintText: 'Contoh: Gudang Cikarang A',
            controller: p.warehouseLocationController,
            prefixIcon: Icons.store_outlined,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.stelVersion,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Nomor QA/STEL/Versi',
            controller: p.stelVersionController,
            prefixIcon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.qaExpiryDate,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Masa Berlaku QA',
            hintText: 'YYYY-MM-DD',
            controller: p.qaExpiryDateController,
            prefixIcon: Icons.date_range_outlined,
          ),
          const SizedBox(height: 12),
          _buildGeneralInput(
            field: QCMaterialGeneralField.tkdnNumber,
            provider: p,
            fieldContexts: fieldContexts,
            label: 'Nomor Sertifikat TKDN',
            controller: p.tkdnNumberController,
            prefixIcon: Icons.shield_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGeneralInput(
                  field: QCMaterialGeneralField.tkdnCertDate,
                  provider: p,
                  fieldContexts: fieldContexts,
                  label: 'Tgl Sertifikat TKDN',
                  controller: p.tkdnCertDateController,
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGeneralInput(
                  field: QCMaterialGeneralField.tkdnValue,
                  provider: p,
                  fieldContexts: fieldContexts,
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

  Widget _buildGeneralInput({
    Key? key,
    required QCMaterialGeneralField field,
    required QCMaterialFormProvider provider,
    required Map<QCMaterialGeneralField, BuildContext> fieldContexts,
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? helperText,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return Builder(
      builder: (context) {
        fieldContexts[field] = context;
        return AppInput(
          key: key,
          label: label,
          controller: controller,
          hintText: hintText,
          helperText: helperText,
          keyboardType: keyboardType,
          prefixIcon: prefixIcon,
          errorText: provider.generalFieldError(field),
          onChanged: (_) => provider.clearGeneralFieldError(field),
        );
      },
    );
  }

  Widget _buildLocationSection(
    QCMaterialFormProvider p,
    Map<QCMaterialGeneralField, BuildContext> fieldContexts,
  ) {
    return Builder(
      builder: (context) {
        fieldContexts[QCMaterialGeneralField.workLocation] = context;
        fieldContexts[QCMaterialGeneralField.customLocationName] = context;
        fieldContexts[QCMaterialGeneralField.customLocationArea] = context;
        fieldContexts[QCMaterialGeneralField.customLocationSegment] = context;
        return WorkLocationSelector(
          selectedSite: p.selectedSite,
          isCustom: p.isCustomLocation,
          nameController: p.customLocNameController,
          areaController: p.customLocAreaController,
          segmentController: p.customLocSegmentController,
          noteController: p.customLocNoteController,
          onSiteChanged: (site) => p.setSelectedSite(site),
          onModeChanged: (custom) => p.setIsCustomLocation(custom),
          locationErrorText: p.generalFieldError(
            QCMaterialGeneralField.workLocation,
          ),
          nameErrorText: p.generalFieldError(
            QCMaterialGeneralField.customLocationName,
          ),
          areaErrorText: p.generalFieldError(
            QCMaterialGeneralField.customLocationArea,
          ),
          segmentErrorText: p.generalFieldError(
            QCMaterialGeneralField.customLocationSegment,
          ),
          onNameChanged: (_) => p.clearGeneralFieldError(
            QCMaterialGeneralField.customLocationName,
          ),
          onAreaChanged: (_) => p.clearGeneralFieldError(
            QCMaterialGeneralField.customLocationArea,
          ),
          onSegmentChanged: (_) => p.clearGeneralFieldError(
            QCMaterialGeneralField.customLocationSegment,
          ),
        );
      },
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
                minValue: item.minValue ?? item.validationRule?.minValue,
                maxValue: item.maxValue ?? item.validationRule?.maxValue,
                choices: item.choices,
                choiceOptions: item.choiceOptions,
                currentStatus: answer.status,
                resultValue: answer.value,
                issueDescription: answer.issueNote ?? '',
                photos: answer.photoPaths,
                localPhotos: p.localItemPhotos[index],
                localPhotoBytes: p.localItemPhotoBytes[index],
                processingPhotos: p.processingItemPhotos[index],
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
        label: 'Catatan Staff Warehouse (Opsional)',
        hintText:
            'Tuliskan catatan tambahan mengenai hasil pengujian material...',
        controller: p.staffNoteController,
        maxLines: 3,
      ),
    );
  }

  Widget _buildSampleNoteCard(QCMaterialFormProvider p) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: AppInput(
        key: ValueKey('sample_note_${p.currentSample!.id}'),
        label: 'Catatan Sampel ${p.currentSample!.sampleNumber} (Opsional)',
        hintText: 'Tuliskan catatan khusus untuk sampel ini...',
        controller: p.currentSample!.notesController,
        onChanged: p.updateSampleNotes,
        maxLines: 3,
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    QCMaterialFormProvider p,
    Map<QCMaterialGeneralField, BuildContext> generalFieldContexts,
  ) {
    final navigationDisabled = p.isPersisting || p.isNavigating;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('qc_material_back_button'),
                text: 'Kembali',
                icon: Icons.arrow_back,
                variant: AppButtonVariant.ghost,
                onPressed: navigationDisabled || p.isFirstStep
                    ? null
                    : () => p.previousStep(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: p.isFinalStep
                  ? AppButton(
                      key: const Key('qc_material_submit_button'),
                      text: p.isRevisionMode ? 'Kirim Ulang' : 'Kirim Laporan',
                      variant: AppButtonVariant.primary,
                      isLoading: p.isPersisting,
                      onPressed: navigationDisabled
                          ? null
                          : () => _submit(context, p),
                    )
                  : AppButton(
                      key: const Key('qc_material_next_button'),
                      text: 'Selanjutnya',
                      icon: Icons.arrow_forward,
                      variant: AppButtonVariant.primary,
                      onPressed: navigationDisabled
                          ? null
                          : () async {
                               final previousStep = p.currentStep;
                               final error = await p.nextStep();
                               if (!mounted) return;
                               if (error == null) {
                                 final currentCtx = context.mounted ? context : this.context;
                                 if (p.isSamplingDecisionRequired) {
                                   await _showSamplingDecisionDialog(currentCtx, p);
                                   return;
                                 }
                                 if (p.currentStep != previousStep) {
                                   _handleSuccessfulNext(p);
                                 }
                                 return;
                               }
                               final invalidField = p.firstInvalidGeneralField;
                               final invalidContext =
                                   generalFieldContexts[invalidField];
                               if (invalidContext != null &&
                                   invalidContext.mounted) {
                                 await Scrollable.ensureVisible(
                                   invalidContext,
                                   alignment: 0.1,
                                   duration: const Duration(milliseconds: 250),
                                   curve: Curves.easeOut,
                                 );
                               }
                               if (!mounted) return;
                               final snackCtx = context.mounted ? context : this.context;
                               AppSnackbar.error(snackCtx, error);
                             },
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!p.isRevisionMode) ...[
          AppButton(
            key: const Key('qc_material_save_draft_button'),
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
                    try {
                      await p.persistReport(QCReportStatus.DRAFT);
                      if (!mounted) return;
                      final currentCtx = context.mounted ? context : this.context;
                      AppSnackbar.success(currentCtx, 'Draft berhasil disimpan');
                      currentCtx.pop();
                    } on QCMaterialPersistenceException catch (error) {
                      if (!mounted) return;
                      final currentCtx = context.mounted ? context : this.context;
                      AppSnackbar.error(currentCtx, error.message);
                    }
                  },
          ),
        ],
      ],
    );
  }

  void _handleSuccessfulNext(QCMaterialFormProvider provider) {
    final eligibilityBecameActive =
        provider.isSamplingWarningActive && !_eligibilityAtLastNavigation;
    _eligibilityAtLastNavigation = provider.isSamplingWarningActive;
    if (eligibilityBecameActive && !_hasHighlightedReviewEligibility) {
      _startReviewWarningHighlight();
    }
    _scheduleScrollToTop();
  }

  void _startReviewWarningHighlight() {
    _hasHighlightedReviewEligibility = true;
    _reviewHighlightTimer?.cancel();
    setState(() => _highlightReviewWarning = true);
    _reviewHighlightTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _highlightReviewWarning = false);
    });
  }

  void _scheduleScrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      unawaited(_animateScrollToTop());
    });
  }

  Future<void> _animateScrollToTop() async {
    try {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (_) {
      // The route may be disposed while the post-navigation animation runs.
    }
  }

  void _submit(BuildContext context, QCMaterialFormProvider p) {
    if (p.hasProcessingPhotos) {
      AppSnackbar.warning(context, qcPhotoProcessingMessage);
      return;
    }
    if (p.isSamplingStopped) {
      AppSnackbar.warning(
        context,
        'Pemeriksaan telah dihentikan. Simpan laporan sebagai draft.',
      );
      return;
    }
    final error = p.validateCurrentStep();
    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    p.completeCurrentSample();
    if (p.isSamplingDecisionRequired) {
      unawaited(_showSamplingDecisionDialog(context, p));
      return;
    }
    showDialog(
      context: context,
      builder: (c) => ConfirmationModal(
        title: p.isRevisionMode ? 'Kirim Ulang Laporan' : 'Kirim Laporan QC',
        message: p.isRevisionMode
            ? 'Apakah perbaikan data pengujian sudah benar dan siap dikirim ulang?'
            : 'Apakah seluruh data pengujian sudah benar dan siap dikirim?',
        confirmText: p.isRevisionMode ? 'Kirim Ulang' : 'Kirim',
        onConfirm: () async {
          Navigator.pop(c);
          p.completeCurrentSample();
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
  }

  Future<void> _showSamplingDecisionDialog(
    BuildContext context,
    QCMaterialFormProvider provider,
  ) async {
    if (!provider.isSamplingDecisionRequired ||
        provider.hasSamplingDecision ||
        !mounted) {
      return;
    }
    final dialogCtx = context.mounted ? context : this.context;
    final result = await showDialog<_SamplingDecisionResult>(
      context: dialogCtx,
      barrierDismissible: false,
      builder: (_) => const _SamplingDecisionDialog(),
    );
    if (result == null || !mounted) return;

    final decisionError = provider.recordSamplingDecision(
      decision: result.type,
      stopReason: result.stopReason,
    );
    if (decisionError != null) {
      final snackCtx = context.mounted ? context : this.context;
      AppSnackbar.error(snackCtx, decisionError);
      return;
    }
    if (result.type == QCMaterialSamplingDecisionType.stop) {
      _scheduleScrollToTop();
      return;
    }

    final previousStep = provider.currentStep;
    final navigationError = await provider.nextStep();
    if (!mounted) return;
    if (navigationError != null) {
      final snackCtx = context.mounted ? context : this.context;
      AppSnackbar.error(snackCtx, navigationError);
      return;
    }
    if (provider.currentStep != previousStep) {
      _handleSuccessfulNext(provider);
    } else {
      _scheduleScrollToTop();
    }
  }
}

class _SamplingDecisionResult {
  final QCMaterialSamplingDecisionType type;
  final String? stopReason;

  const _SamplingDecisionResult(this.type, {this.stopReason});
}

class _SamplingDecisionDialog extends StatefulWidget {
  const _SamplingDecisionDialog();

  @override
  State<_SamplingDecisionDialog> createState() =>
      _SamplingDecisionDialogState();
}

class _SamplingDecisionDialogState extends State<_SamplingDecisionDialog> {
  final TextEditingController _stopReasonController = TextEditingController();
  String? _stopReasonError;

  @override
  void dispose() {
    _stopReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dialogBackgroundColor: AppColors.surface,
      ),
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Peringatan Sampling Material',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sedikitnya dua sampel yang telah selesai diperiksa tidak sesuai standar. '
                'Material terindikasi tidak memenuhi standar, dapat dikembalikan '
                'kepada vendor, dan laporan memerlukan revisi.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('qc_material_sampling_stop_reason'),
                controller: _stopReasonController,
                maxLines: 3,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: 'Alasan penghentian',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  hintText: 'Wajib diisi jika pemeriksaan dihentikan',
                  hintStyle: const TextStyle(color: AppColors.textSoft),
                  errorText: _stopReasonError,
                  errorStyle: const TextStyle(color: AppColors.rejectedText),
                  filled: true,
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.rejectedText),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.rejectedText, width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (_stopReasonError == null) return;
                  setState(() => _stopReasonError = null);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('qc_material_stop_inspection_button'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.rejectedText,
            ),
            onPressed: () {
              final reason = _stopReasonController.text.trim();
              if (reason.isEmpty) {
                setState(
                  () => _stopReasonError = 'Alasan penghentian wajib diisi.',
                );
                return;
              }
              Navigator.pop(
                context,
                _SamplingDecisionResult(
                  QCMaterialSamplingDecisionType.stop,
                  stopReason: reason,
                ),
              );
            },
            child: const Text('Hentikan Pemeriksaan'),
          ),
          FilledButton(
            key: const Key('qc_material_continue_inspection_button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
            ),
            onPressed: () => Navigator.pop(
              context,
              const _SamplingDecisionResult(
                QCMaterialSamplingDecisionType.continueInspection,
              ),
            ),
            child: const Text('Lanjutkan Pemeriksaan'),
          ),
        ],
      ),
    );
  }
}
