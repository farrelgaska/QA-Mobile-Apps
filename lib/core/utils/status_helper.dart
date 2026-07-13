import 'package:flutter/material.dart';
import '../../shared/models/enums.dart';
import '../constants/app_colors.dart';

class StatusHelper {
  // --- ReportStatus (Old) helpers ---
  static String getReportStatusLabel(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.menunggu:
        return 'Menunggu Review';
      case ReportStatus.disetujui:
        return 'Disetujui';
      case ReportStatus.ditolak:
      case ReportStatus.revisi:
      case ReportStatus.perluTindakLanjut:
        return 'Perlu Tindak Lanjut';
    }
  }

  static Color getReportStatusTextColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return const Color(0xFF6B7280); // Grey Text
      case ReportStatus.menunggu:
        return const Color(0xFFF59E0B); // Pending Orange Text
      case ReportStatus.disetujui:
        return const Color(0xFF006B5A); // Green Text
      case ReportStatus.ditolak:
      case ReportStatus.revisi:
      case ReportStatus.perluTindakLanjut:
        return const Color(0xFFEF4444); // Red Text
    }
  }

  static Color getReportStatusBgColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return const Color(0xFFF3F4F6); // Grey Bg
      case ReportStatus.menunggu:
        return const Color(0xFFFFF4E5); // Pending Orange Soft Bg
      case ReportStatus.disetujui:
        return const Color(0xFFE8F7F1); // Green Soft Bg
      case ReportStatus.ditolak:
      case ReportStatus.revisi:
      case ReportStatus.perluTindakLanjut:
        return const Color(0xFFFDECEC); // Red Soft Bg
    }
  }

  // --- ChecklistStatus helpers ---
  static String getChecklistStatusLabel(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.belumDiisi:
        return 'Belum Diisi';
      case ChecklistStatus.sudahDiisi:
        return 'Sudah Diisi';
      case ChecklistStatus.inputTidakValid:
        return 'Input Tidak Valid';
      case ChecklistStatus.perluDilengkapi:
        return 'Perlu Dilengkapi';
      case ChecklistStatus.lulus:
        return 'Lulus';
      case ChecklistStatus.tidakSesuai:
        return 'Tidak Sesuai';
      case ChecklistStatus.perluTindakLanjut:
        return 'Perlu Tindak Lanjut';
    }
  }

  static Color getChecklistStatusTextColor(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.belumDiisi:
        return const Color(0xFF6B7280);
      case ChecklistStatus.sudahDiisi:
        return const Color(0xFF2563EB); // Blue
      case ChecklistStatus.inputTidakValid:
        return const Color(0xFFEF4444); // Red
      case ChecklistStatus.perluDilengkapi:
        return const Color(0xFFF59E0B); // Orange
      case ChecklistStatus.lulus:
        return const Color(0xFF006B5A);
      case ChecklistStatus.tidakSesuai:
      case ChecklistStatus.perluTindakLanjut:
        return const Color(0xFFEF4444);
    }
  }

  static Color getChecklistStatusBgColor(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.belumDiisi:
        return const Color(0xFFF3F4F6);
      case ChecklistStatus.sudahDiisi:
        return const Color(0xFFE8EEFF); // Soft blue
      case ChecklistStatus.inputTidakValid:
        return const Color(0xFFFDECEC); // Soft red
      case ChecklistStatus.perluDilengkapi:
        return const Color(0xFFFFF4E5); // Soft orange
      case ChecklistStatus.lulus:
        return const Color(0xFFE8F7F1);
      case ChecklistStatus.tidakSesuai:
      case ChecklistStatus.perluTindakLanjut:
        return const Color(0xFFFDECEC);
    }
  }

  // --- QCReportStatus (New) helpers ---
  static QCReportStatus normalizeStatus(dynamic status) {
    if (status is QCReportStatus) return status;
    if (status is ReportStatus) {
      switch (status) {
        case ReportStatus.draft:
          return QCReportStatus.DRAFT;
        case ReportStatus.menunggu:
          return QCReportStatus.SUBMITTED;
        case ReportStatus.disetujui:
          return QCReportStatus.APPROVED;
        case ReportStatus.revisi:
        case ReportStatus.perluTindakLanjut:
        case ReportStatus.ditolak:
          return QCReportStatus.NEEDS_FOLLOW_UP;
      }
    }
    if (status is String) {
      final val = status.toUpperCase().trim();
      if (val == 'DRAFT') return QCReportStatus.DRAFT;
      if (val == 'SUBMITTED' || val == 'WAITING' || val == 'MENUNGGU' || val == 'MENUNGGU REVIEW' || val == 'PENDING') {
        return QCReportStatus.SUBMITTED;
      }
      if (val == 'APPROVED' || val == 'DISETUJUI' || val == 'LULUS' || val == 'SELESAI') {
        return QCReportStatus.APPROVED;
      }
      if (val == 'NEEDS_FOLLOW_UP' || val == 'NEEDFOLLOWUP' || val == 'NEED_FOLLOW_UP' || val == 'REVISI' || val == 'PERLU PERBAIKAN' || val == 'PERLU TINDAK LANJUT' || val == 'DITOLAK') {
        return QCReportStatus.NEEDS_FOLLOW_UP;
      }
    }
    return QCReportStatus.DRAFT;
  }

  static String getQCReportStatusLabel(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.DRAFT:
        return 'Draft';
      case QCReportStatus.SUBMITTED:
        return 'Menunggu Review';
      case QCReportStatus.NEEDS_FOLLOW_UP:
        return 'Perlu Tindak Lanjut';
      case QCReportStatus.APPROVED:
        return 'Disetujui';
    }
  }

  static Color getQCReportStatusTextColor(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.DRAFT:
        return const Color(0xFF6B7280);
      case QCReportStatus.SUBMITTED:
        return const Color(0xFFF59E0B);
      case QCReportStatus.APPROVED:
        return const Color(0xFF006B5A);
      case QCReportStatus.NEEDS_FOLLOW_UP:
        return const Color(0xFFEF4444);
    }
  }

  static Color getQCReportStatusBgColor(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.DRAFT:
        return const Color(0xFFF3F4F6);
      case QCReportStatus.SUBMITTED:
        return const Color(0xFFFFF4E5);
      case QCReportStatus.APPROVED:
        return const Color(0xFFE8F7F1);
      case QCReportStatus.NEEDS_FOLLOW_UP:
        return const Color(0xFFFDECEC);
    }
  }

  // --- QCResultStatus (New) helpers ---
  static String getQCResultStatusLabel(QCResultStatus status) {
    switch (status) {
      case QCResultStatus.notFilled:
        return 'Belum Diisi';
      case QCResultStatus.pass:
        return 'Lulus';
      case QCResultStatus.fail:
        return 'Tidak Sesuai';
      case QCResultStatus.needFollowUp:
        return 'Perlu Tindak Lanjut';
    }
  }

  static Color getQCResultStatusTextColor(QCResultStatus status) {
    switch (status) {
      case QCResultStatus.notFilled:
        return AppColors.inactiveText;
      case QCResultStatus.pass:
        return AppColors.approvedText;
      case QCResultStatus.fail:
      case QCResultStatus.needFollowUp:
        return AppColors.rejectedText;
    }
  }

  static Color getQCResultStatusBgColor(QCResultStatus status) {
    switch (status) {
      case QCResultStatus.notFilled:
        return AppColors.inactiveBg;
      case QCResultStatus.pass:
        return AppColors.approvedBg;
      case QCResultStatus.fail:
      case QCResultStatus.needFollowUp:
        return AppColors.rejectedBg;
    }
  }
}
