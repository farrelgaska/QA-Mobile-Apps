import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_qc_material_templates.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/qc_checklist_answer_model.dart';
import '../../../shared/models/qc_material_evaluation_model.dart';
import '../../../shared/models/qc_material_template_model.dart';
import '../../../shared/models/qc_report_model.dart';
import '../../../shared/models/qc_report_sample_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/photo_grid.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/status_badge.dart';

class RenderItem {
  final String? itemId;
  final String label;
  final String standard;
  final String value;
  final dynamic status; // ChecklistStatus or QCResultStatus
  final String? warningMessage;
  final String issueNote;
  final List<String> photos;
  final String? unit;
  final String? adminNote;

  RenderItem({
    this.itemId,
    required this.label,
    required this.standard,
    required this.value,
    required this.status,
    this.warningMessage,
    required this.issueNote,
    required this.photos,
    this.unit,
    this.adminNote,
  });
}

List<RenderItem> resolveReportDetailItems(QCReportModel report) {
  final answersByItemId = {
    for (final answer in report.checklistItems) answer.itemId: answer,
  };
  return answersByItemId.values
      .map(
        (answer) => RenderItem(
          itemId: answer.itemId,
          label: answer.paramName,
          standard: answer.standardText,
          value: answer.value?.toString() ?? '',
          status: QCResultStatus.notFilled,
          issueNote: answer.issueNote ?? '',
          photos: answer.photoPaths,
          unit: answer.unit,
          adminNote: answer.adminNote,
        ),
      )
      .toList(growable: false);
}

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _adminNoteController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await DummyState().fetchReportsFromApi();
    } catch (e) {
      _errorMessage = 'Gagal memuat detail laporan: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _adminNoteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final state = DummyState();

    // Find the report index
    final reportIdx = state.reports.indexWhere((r) => r.id == widget.reportId);

    if (_isLoading && reportIdx == -1) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null && reportIdx == -1) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.rejectedText,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 120,
                    height: 38,
                    child: AppButton(
                      text: 'Coba Lagi',
                      variant: AppButtonVariant.secondary,
                      onPressed: _fetchDetail,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Find the report
    final report = reportIdx != -1
        ? state.reports[reportIdx]
        : (state.reports.isNotEmpty ? state.reports[0] : null);

    if (report == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Laporan tidak ditemukan',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final isEditable =
        report.status == QCReportStatus.DRAFT ||
        report.status == QCReportStatus.NEEDS_FOLLOW_UP;

    final renderItems = resolveReportDetailItems(report);

    final decision = QCMaterialSamplingDecision.fromGeneralInfo(
      report.generalInfo,
    );
    final isStopped =
        decision?.type == QCMaterialSamplingDecisionType.stop ||
        report.generalInfo[QCMaterialSamplingDecision.decisionKey] == 'STOP';
    final stopReason =
        decision?.stopReason ??
        report.generalInfo[QCMaterialSamplingDecision.stopReasonKey];

    final isMultiSampleMaterial =
        report.type == QCType.material && report.samples.isNotEmpty;

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
                title: 'Detail Laporan',
                subtitle: report.id,
                actions: [StatusBadge(status: report.status)],
              ),
              const SizedBox(height: 16),

              // Banner Catatan Admin (Perlu Perbaikan)
              if (report.status == QCReportStatus.NEEDS_FOLLOW_UP &&
                  report.adminNote != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.rejectedBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.rejectedText, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: AppColors.rejectedText,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Instruksi Perbaikan',
                            style: TextStyle(
                              color: AppColors.rejectedText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.adminNote!,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // STOP Decision Banner (if sampling stopped)
              if (report.type == QCType.material && isStopped) ...[
                Container(
                  key: const Key('qc_material_stop_decision_banner'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.rejectedBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.rejectedText, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.rejectedText,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Pemeriksaan Dihentikan',
                            style: TextStyle(
                              color: AppColors.rejectedText,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (stopReason != null && stopReason.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Alasan Penghentian: $stopReason',
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Card: Ringkasan Informasi Laporan
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Inspeksi',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Jenis QC',
                      report.type == QCType.material
                          ? 'QC Material'
                          : 'QC Pekerjaan',
                    ),
                    _buildInfoRow('Nama Item', report.title),
                    if (report.formCode.isNotEmpty)
                      _buildInfoRow('Kode Form', report.formCode),
                    _buildInfoRow('Tanggal', _formatDate(report.date)),
                    _buildInfoRow(
                      'Pemeriksa',
                      '${report.checkedByName} (${report.checkedByNik})',
                    ),
                    _buildInfoRow('Site Lokasi', report.siteName),
                    _buildInfoRow('Area / Zona', report.area),
                    _buildInfoRow('Detail Titik', report.detailLocation),
                    if (report.finalConclusion != null &&
                        state.currentUser.isAdmin)
                      _buildInfoRow('Kesimpulan', report.finalConclusion!),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Checklist Results Section
              if (isMultiSampleMaterial) ...[
                const Text(
                  'Hasil Pengujian Per Sampel',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                ...report.samples.map(
                  (sample) => _buildMaterialSampleSection(report, sample),
                ),
              ] else ...[
                const Text(
                  'Hasil Checklist Parameter',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                ...renderItems.map(
                  (result) => _buildSingleChecklistCard(report, result),
                ),
              ],

              // Staff general note card
              if (report.staffNote.isNotEmpty) ...[
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catatan Staff Warehouse',
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.staffNote,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Edit Action Button (visible for draft/needFollowUp)
              if (isEditable) ...[
                AppButton(
                  text: report.status == QCReportStatus.NEEDS_FOLLOW_UP
                      ? 'Perbaiki Laporan'
                      : 'Edit Laporan',
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    final isRevision =
                        report.status == QCReportStatus.NEEDS_FOLLOW_UP;
                    if (report.type == QCType.material) {
                      final tid = report.templateId.isNotEmpty
                          ? report.templateId
                          : 'tiang_besi_7m_3_segmen';
                      final QCMaterialTemplate? cachedTemplate =
                          DummyState().templateCache[tid] ??
                          dummyQCMaterialTemplates
                              .cast<QCMaterialTemplate?>()
                              .firstWhere(
                                (t) => t?.id == tid,
                                orElse: () => null,
                              );
                      context.push(
                        '/qc-material/form/$tid?editReportId=${report.id}${isRevision ? "&isRevision=true" : ""}',
                        extra: cachedTemplate,
                      );
                    } else {
                      final tid = report.templateId;
                      final cachedTemplate =
                          DummyState().workTemplateCache[tid];
                      context.push(
                        '/qc-pekerjaan/form/$tid?editReportId=${report.id}${isRevision ? "&isRevision=true" : ""}',
                        extra: cachedTemplate,
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialSampleSection(
    QCReportModel report,
    QCReportSample sample,
  ) {
    return Container(
      key: Key('sample_section_${sample.sampleNumber}'),
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sampel ${sample.sampleNumber}',
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (sample.inspectionStatus == QCSampleInspectionStatus.completed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.approvedBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(
                      color: AppColors.approvedText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...sample.checklistAnswers.map(
            (answer) => _buildChecklistAnswerCard(report, answer),
          ),
          if (sample.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catatan Sampel:',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sample.notes,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (sample.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Foto Sampel:',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            PhotoGrid(photos: sample.photoPaths),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistAnswerCard(
    QCReportModel report,
    QCChecklistAnswer answer,
  ) {
    final bool itemNeedsFollowUp =
        report.status == QCReportStatus.NEEDS_FOLLOW_UP &&
        (answer.adminNote != null && answer.adminNote!.trim().isNotEmpty);
    final hasIssue = answer.issueNote != null && answer.issueNote!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        color: itemNeedsFollowUp ? const Color(0xFFFFF5F5) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              answer.paramName,
              style: const TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Standar: ${answer.standardText}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSoft, height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                const Text(
                  'Hasil Input:',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Text(
                  (answer.value?.toString().isEmpty ?? true)
                      ? '-'
                      : '${answer.value} ${answer.unit ?? ""}'.trim(),
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            if (answer.warningMessage != null &&
                answer.warningMessage!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.warning,
                    color: AppColors.rejectedText,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    answer.warningMessage!,
                    style: const TextStyle(
                      color: AppColors.rejectedText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            if (hasIssue && answer.issueNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rejectedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Masalah:',
                      style: TextStyle(
                        color: AppColors.rejectedText,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      answer.issueNote!,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (answer.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Foto Bukti Fisik:',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              PhotoGrid(photos: answer.photoPaths),
            ],

            if (itemNeedsFollowUp &&
                answer.adminNote != null &&
                answer.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rejectedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.rejectedText, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.rejectedText,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Catatan Evaluasi Admin:',
                          style: TextStyle(
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
          ],
        ),
      ),
    );
  }

  Widget _buildSingleChecklistCard(QCReportModel report, RenderItem result) {
    final hasIssue =
        result.status == ChecklistStatus.tidakSesuai ||
        result.status == ChecklistStatus.perluTindakLanjut ||
        result.status == QCResultStatus.fail ||
        result.status == QCResultStatus.needFollowUp;

    final bool itemNeedsFollowUp =
        report.status == QCReportStatus.NEEDS_FOLLOW_UP &&
        (result.adminNote != null && result.adminNote!.trim().isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        color: itemNeedsFollowUp ? const Color(0xFFFFF5F5) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    result.label,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Standar: ${result.standard}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSoft, height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                const Text(
                  'Hasil Input:',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Text(
                  result.value.isEmpty
                      ? '-'
                      : '${result.value} ${result.unit ?? ""}'.trim(),
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            if (result.warningMessage != null &&
                result.warningMessage!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.warning,
                    color: AppColors.rejectedText,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    result.warningMessage!,
                    style: const TextStyle(
                      color: AppColors.rejectedText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            if (hasIssue && result.issueNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rejectedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Masalah:',
                      style: TextStyle(
                        color: AppColors.rejectedText,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.issueNote,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (result.photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Foto Bukti Fisik:',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              PhotoGrid(photos: result.photos),
            ],

            if (itemNeedsFollowUp &&
                result.adminNote != null &&
                result.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rejectedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.rejectedText, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.rejectedText,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Catatan Evaluasi Admin:',
                          style: TextStyle(
                            color: AppColors.rejectedText,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.adminNote!,
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
