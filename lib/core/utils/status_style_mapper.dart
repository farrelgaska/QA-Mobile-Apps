import 'package:flutter/material.dart';

class StatusStyle {
  final Color background;
  final Color foreground;
  final Color? border;

  const StatusStyle({
    required this.background,
    required this.foreground,
    this.border,
  });
}

class StatusStyleMapper {
  static StatusStyle getStyle(dynamic status) {
    String statusStr = '';
    if (status is String) {
      statusStr = status;
    } else if (status != null) {
      statusStr = status.toString();
    }

    final normalized = statusStr.toLowerCase().trim();

    if (normalized == 'draft' ||
        normalized == 'qcreportstatus.draft' ||
        normalized == 'reportstatus.draft') {
      return const StatusStyle(
        background: Color(0xFFF3F4F6),
        foreground: Color(0xFF6B7280),
        border: Color(0xFFE5E7EB),
      );
    }

    if (normalized == 'pending' ||
        normalized == 'menunggu' ||
        normalized == 'menunggu review' ||
        normalized == 'menunggu review admin' ||
        normalized == 'pending review' ||
        normalized == 'on progress' ||
        normalized == 'waiting' ||
        normalized == 'notevaluated' ||
        normalized == 'qcreportstatus.waiting' ||
        normalized == 'reportstatus.menunggu' ||
        normalized == 'qcresultstatus.notfilled' ||
        normalized == 'checkliststatus.belumdiisi') {
      return const StatusStyle(
        background: Color(0xFFFFF4E5),
        foreground: Color(0xFFF59E0B),
      );
    }

    if (normalized == 'lulus' ||
        normalized == 'disetujui' ||
        normalized == 'selesai' ||
        normalized == 'diterima' ||
        normalized == 'pass' ||
        normalized == 'aktif' ||
        normalized == 'active' ||
        normalized == 'qcreportstatus.approved' ||
        normalized == 'reportstatus.disetujui' ||
        normalized == 'qcresultstatus.pass' ||
        normalized == 'checkliststatus.lulus') {
      return const StatusStyle(
        background: Color(0xFFE8F7F1),
        foreground: Color(0xFF006B5A),
      );
    }

    if (normalized == 'perlu perbaikan' ||
        normalized == 'tidak sesuai' ||
        normalized == 'revisi' ||
        normalized == 'tindak lanjut' ||
        normalized == 'perlu tindak lanjut' ||
        normalized == 'butuh revisi' ||
        normalized == 'fail' ||
        normalized == 'needfollowup' ||
        normalized == 'qcreportstatus.needfollowup' ||
        normalized == 'qcreportstatus.rejected' ||
        normalized == 'reportstatus.revisi' ||
        normalized == 'reportstatus.ditolak' ||
        normalized == 'reportstatus.perlutindaklanjut' ||
        normalized == 'qcresultstatus.fail' ||
        normalized == 'qcresultstatus.needfollowup' ||
        normalized == 'checkliststatus.tidaksesuai' ||
        normalized == 'checkliststatus.perlutindaklanjut') {
      return const StatusStyle(
        background: Color(0xFFFDECEC),
        foreground: Color(0xFFEF4444),
      );
    }

    // Default Info / Blue
    return const StatusStyle(
      background: Color(0xFFE8EEFF),
      foreground: Color(0xFF2563EB),
    );
  }
}
