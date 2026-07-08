import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/status_helper.dart';
import '../../shared/models/enums.dart';

class StatusBadge extends StatelessWidget {
  final dynamic status; // ReportStatus, ChecklistStatus, QCReportStatus, QCResultStatus or String

  const StatusBadge({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String label = '';
    Color textColor = AppColors.textMuted;
    Color bgColor = AppColors.backgroundSoft;

    if (status is ReportStatus) {
      label = StatusHelper.getReportStatusLabel(status as ReportStatus);
      textColor = StatusHelper.getReportStatusTextColor(status as ReportStatus);
      bgColor = StatusHelper.getReportStatusBgColor(status as ReportStatus);
    } else if (status is ChecklistStatus) {
      label = StatusHelper.getChecklistStatusLabel(status as ChecklistStatus);
      textColor = StatusHelper.getChecklistStatusTextColor(status as ChecklistStatus);
      bgColor = StatusHelper.getChecklistStatusBgColor(status as ChecklistStatus);
    } else if (status is QCReportStatus) {
      label = StatusHelper.getQCReportStatusLabel(status as QCReportStatus);
      textColor = StatusHelper.getQCReportStatusTextColor(status as QCReportStatus);
      bgColor = StatusHelper.getQCReportStatusBgColor(status as QCReportStatus);
    } else if (status is QCResultStatus) {
      label = StatusHelper.getQCResultStatusLabel(status as QCResultStatus);
      textColor = StatusHelper.getQCResultStatusTextColor(status as QCResultStatus);
      bgColor = StatusHelper.getQCResultStatusBgColor(status as QCResultStatus);
    } else if (status is String) {
      label = status as String;
      final lowerLabel = label.toLowerCase();
      if (lowerLabel == 'aktif' || lowerLabel == 'lulus' || lowerLabel == 'disetujui' || lowerLabel == 'diterima' || lowerLabel == 'selesai') {
        textColor = AppColors.approvedText;
        bgColor = AppColors.approvedBg;
      } else if (lowerLabel == 'nonaktif' || lowerLabel == 'ditolak' || lowerLabel == 'pending') {
        label = 'Pending';
        textColor = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFFF4E5);
      } else if (lowerLabel == 'menunggu' || lowerLabel == 'on progress') {
        textColor = AppColors.waitingText;
        bgColor = AppColors.waitingBg;
      } else if (lowerLabel == 'revisi' || lowerLabel == 'tindak lanjut' || lowerLabel == 'perlu tindak lanjut' || lowerLabel == 'butuh revisi' || lowerLabel == 'perlu perbaikan') {
        label = 'Perlu Perbaikan';
        textColor = AppColors.rejectedText; // Merah pastel
        bgColor = AppColors.rejectedBg;
      } else {
        textColor = AppColors.textMuted;
        bgColor = AppColors.backgroundSoft;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
