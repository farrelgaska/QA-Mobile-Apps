import 'package:flutter/material.dart';
import '../../core/utils/status_helper.dart';
import '../../core/utils/status_style_mapper.dart';
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

    if (status is ReportStatus) {
      label = StatusHelper.getReportStatusLabel(status as ReportStatus);
    } else if (status is ChecklistStatus) {
      label = StatusHelper.getChecklistStatusLabel(status as ChecklistStatus);
    } else if (status is QCReportStatus) {
      label = StatusHelper.getQCReportStatusLabel(status as QCReportStatus);
    } else if (status is QCResultStatus) {
      label = StatusHelper.getQCResultStatusLabel(status as QCResultStatus);
    } else if (status is String) {
      label = status as String;
      final lowerLabel = label.toLowerCase();
      if (lowerLabel == 'aktif' || lowerLabel == 'lulus' || lowerLabel == 'disetujui' || lowerLabel == 'diterima' || lowerLabel == 'selesai' || lowerLabel == 'pass') {
        label = 'Lulus';
      } else if (lowerLabel == 'tindak lanjut' || lowerLabel == 'perlu tindak lanjut' || lowerLabel == 'needfollowup' || lowerLabel == 'revisi' || lowerLabel == 'butuh revisi') {
        label = 'Perlu Tindak Lanjut';
      } else if (lowerLabel == 'perlu perbaikan' || lowerLabel == 'tidak sesuai' || lowerLabel == 'fail') {
        label = 'Perlu Perbaikan';
      } else if (lowerLabel == 'nonaktif' || lowerLabel == 'ditolak' || lowerLabel == 'pending' || lowerLabel == 'menunggu' || lowerLabel == 'on progress' || lowerLabel == 'menunggu review admin') {
        label = 'Pending';
      }
    }

    final style = StatusStyleMapper.getStyle(status is String ? label : status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(100),
        border: style.border != null ? Border.all(color: style.border!, width: 1) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
