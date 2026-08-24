import 'package:flutter/material.dart';
import '../../core/utils/status_helper.dart';
import '../../core/utils/status_style_mapper.dart';
import '../../shared/models/enums.dart';

class StatusBadge extends StatelessWidget {
  final dynamic
      status; // ReportStatus, ChecklistStatus, QCReportStatus, QCResultStatus or String

  const StatusBadge({
    super.key,
    required this.status,
  });

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
      if (lowerLabel == 'aktif') {
        label = 'Aktif';
      } else if (lowerLabel == 'nonaktif') {
        label = 'Nonaktif';
      } else if (lowerLabel == 'disetujui' ||
          lowerLabel == 'diterima' ||
          lowerLabel == 'selesai') {
        label = 'Disetujui';
      } else if (lowerLabel == 'lulus' ||
          lowerLabel == 'pass' ||
          lowerLabel == 'sesuai standar') {
        label = 'Sesuai Standar';
      } else if (lowerLabel == 'tindak lanjut' ||
          lowerLabel == 'perlu tindak lanjut' ||
          lowerLabel == 'needfollowup' ||
          lowerLabel == 'revisi' ||
          lowerLabel == 'butuh revisi') {
        label = 'Perlu Tindak Lanjut';
      } else if (lowerLabel == 'perlu perbaikan' || lowerLabel == 'ditolak') {
        label = 'Perlu Tindak Lanjut';
      } else if (lowerLabel == 'tidak sesuai' || lowerLabel == 'fail') {
        label = 'Tidak Sesuai Standar';
      } else if (lowerLabel == 'dikirim' ||
          lowerLabel == 'pending' ||
          lowerLabel == 'menunggu' ||
          lowerLabel == 'on progress' ||
          lowerLabel == 'menunggu review admin') {
        label = 'Dikirim';
      }
    }

    final style = StatusStyleMapper.getStyle(status is String ? label : status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(100),
        border: style.border != null
            ? Border.all(color: style.border!, width: 1)
            : null,
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
