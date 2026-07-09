import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../core/dummy/dummy_qc_material_templates.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/photo_grid.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../admin/services/qc_evaluation_service.dart';

class RenderItem {
  final String label;
  final String standard;
  final String value;
  final dynamic status; // ChecklistStatus or QCResultStatus
  final String? warningMessage;
  final String issueNote;
  final List<String> photos;
  final String? unit;

  RenderItem({
    required this.label,
    required this.standard,
    required this.value,
    required this.status,
    this.warningMessage,
    required this.issueNote,
    required this.photos,
    this.unit,
  });
}

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({
    Key? key,
    required this.reportId,
  }) : super(key: key);

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _adminNoteController = TextEditingController();

  @override
  void dispose() {
    _adminNoteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final state = DummyState();
    
    // Find the report
    final report = state.reports.firstWhere(
      (r) => r.id == widget.reportId,
      orElse: () => state.reports[0],
    );

    final isEditable = report.status == QCReportStatus.draft || report.status == QCReportStatus.needFollowUp;

    // Build unified render items list
    final List<RenderItem> renderItems = [];
    if (report.checklistAnswers != null && report.checklistAnswers!.isNotEmpty) {
      for (var ans in report.checklistAnswers!) {
        dynamic evalStatus = ans.status;
        String? warning = ans.warningMessage;
        if (state.currentUser.role == 'Admin' && report.status == QCReportStatus.waiting) {
          final template = dummyQCMaterialTemplates.firstWhere(
            (t) => t.code == report.formCode,
            orElse: () => dummyQCMaterialTemplates[0],
          );
          final item = template.checklistItems.firstWhere(
            (it) => it.id == ans.itemId,
            orElse: () => template.checklistItems[0],
          );
          evalStatus = QCEvaluationService.evaluateMaterialItem(
            item: item,
            value: ans.value?.toString() ?? '',
          );
          if (evalStatus == QCResultStatus.fail) {
            warning = 'Kondisi tidak sesuai standar';
          } else {
            warning = null;
          }
        }

        renderItems.add(
          RenderItem(
            label: ans.paramName ?? 'Parameter',
            standard: ans.standardText ?? 'Standard',
            value: ans.value?.toString() ?? '',
            status: evalStatus,
            warningMessage: warning,
            issueNote: ans.issueNote ?? '',
            photos: ans.photoPaths,
            unit: ans.unit,
          ),
        );
      }
    } else if (report.checklistResults != null) {
      for (var res in report.checklistResults!) {
        dynamic evalStatus = res.status;
        if (state.currentUser.role == 'Admin' && report.status == QCReportStatus.waiting) {
          evalStatus = QCEvaluationService.evaluatePekerjaanItem(
            title: res.paramName,
            inputType: res.inputType == 'Angka' ? InputType.number : (res.inputType == 'Pilihan' ? InputType.choice : InputType.text),
            value: res.resultValue,
          );
        }

        renderItems.add(
          RenderItem(
            label: res.paramName,
            standard: res.standard,
            value: res.resultValue,
            status: evalStatus,
            warningMessage: evalStatus == ChecklistStatus.tidakSesuai ? 'Kondisi tidak sesuai standar' : null,
            issueNote: res.issueNote,
            photos: res.photos,
            unit: res.unit,
          ),
        );
      }
    }

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
                actions: [
                  StatusBadge(status: report.status),
                ],
              ),

              // Banner Catatan Admin (Perlu Perbaikan)
              if (report.status == QCReportStatus.needFollowUp && report.adminNote != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.rejectedBg, // Merah pastel
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.rejectedText, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber, color: AppColors.rejectedText, size: 20),
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
                    _buildInfoRow('Jenis QC', report.type == QCType.material ? 'QC Material' : 'QC Pekerjaan'),
                    _buildInfoRow('Nama Item', report.title),
                    if (report.formCode != null)
                      _buildInfoRow('Kode Form', report.formCode!),
                    _buildInfoRow('Tanggal', _formatDate(report.date)),
                    _buildInfoRow('Pemeriksa', '${report.checkedByName} (${report.checkedByNik})'),
                    _buildInfoRow('Site Lokasi', report.siteName),
                    _buildInfoRow('Area / Zona', report.area),
                    _buildInfoRow('Detail Titik', report.detailLocation),
                    if (report.finalConclusion != null && state.currentUser.role == 'Admin')
                      _buildInfoRow('Kesimpulan', report.finalConclusion!),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Checklist Results Section
              const Text(
                'Hasil Checklist Parameter',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              ...renderItems.map((result) {
                final hasIssue = result.status == ChecklistStatus.tidakSesuai || 
                    result.status == ChecklistStatus.perluTindakLanjut ||
                    result.status == QCResultStatus.fail ||
                    result.status == QCResultStatus.needFollowUp;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
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
                            if (state.currentUser.role == 'Admin') ...[
                              const SizedBox(width: 8),
                              StatusBadge(status: result.status),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Standar: ${result.standard}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.borderSoft, height: 1),
                        const SizedBox(height: 12),

                        // Inputted value
                        Row(
                          children: [
                            const Text(
                              'Hasil Input:',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              result.value.isEmpty ? '-' : '${result.value} ${result.unit ?? ""}',
                              style: const TextStyle(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),

                        if (result.warningMessage != null && result.warningMessage!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.warning, color: AppColors.rejectedText, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                result.warningMessage!,
                                style: const TextStyle(color: AppColors.rejectedText, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],

                        // Issue note if any
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
                                  style: const TextStyle(color: AppColors.textMain, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Photos if any
                        if (result.photos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Foto Bukti Fisik:',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          PhotoGrid(photos: result.photos),
                        ],
                      ],
                    ),
                  ),
                );
              }),

              // Staff general note card
              if (report.staffNote.isNotEmpty) ...[
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catatan QA Staff',
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
                  text: report.status == QCReportStatus.needFollowUp ? 'Perbaiki Laporan' : 'Edit Laporan',
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    // Navigate to form depending on type
                    if (report.type == QCType.material) {
                      String templateId = 'tiang_besi_7m_3_segmen';
                      final titleLower = report.title.toLowerCase();
                      if (titleLower.contains('besi 7')) {
                        templateId = 'tiang_besi_7m_3_segmen';
                      } else if (titleLower.contains('besi 9')) {
                        templateId = 'tiang_besi_9m_3_segmen';
                      } else if (titleLower.contains('7 meter 2')) {
                        templateId = 'tiang_7m_2_segmen';
                      } else if (titleLower.contains('galvanis')) {
                        templateId = 'tiang_galvanis_6m_tanpa_sambungan';
                      } else if (titleLower.contains('beton 7')) {
                        templateId = 'tiang_beton_7m';
                      } else if (titleLower.contains('beton 9')) {
                        templateId = 'tiang_beton_9m';
                      }
                      context.push('/qc-material/form/$templateId?editReportId=${report.id}');
                    } else {
                      context.push('/qc-pekerjaan/form/pek-1?editReportId=${report.id}');
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
