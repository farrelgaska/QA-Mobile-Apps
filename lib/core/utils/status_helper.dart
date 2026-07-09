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
        return 'Perlu Perbaikan';
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

  // --- ChecklistStatus (Old) helpers ---
  static String getChecklistStatusLabel(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.belumDiisi:
        return 'Belum Diisi';
      case ChecklistStatus.lulus:
        return 'Lulus';
      case ChecklistStatus.tidakSesuai:
      case ChecklistStatus.perluTindakLanjut:
        return 'Perlu Perbaikan';
    }
  }

  static Color getChecklistStatusTextColor(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.belumDiisi:
        return const Color(0xFF6B7280);
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
      case ChecklistStatus.lulus:
        return const Color(0xFFE8F7F1);
      case ChecklistStatus.tidakSesuai:
      case ChecklistStatus.perluTindakLanjut:
        return const Color(0xFFFDECEC);
    }
  }

  // --- QCReportStatus (New) helpers ---
  static String getQCReportStatusLabel(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.draft:
        return 'Draft';
      case QCReportStatus.waiting:
        return 'Menunggu Review';
      case QCReportStatus.approved:
        return 'Disetujui';
      case QCReportStatus.rejected:
      case QCReportStatus.needFollowUp:
        return 'Perlu Perbaikan';
    }
  }

  static Color getQCReportStatusTextColor(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.draft:
        return const Color(0xFF6B7280);
      case QCReportStatus.waiting:
        return const Color(0xFFF59E0B);
      case QCReportStatus.approved:
        return const Color(0xFF006B5A);
      case QCReportStatus.rejected:
      case QCReportStatus.needFollowUp:
        return const Color(0xFFEF4444);
    }
  }

  static Color getQCReportStatusBgColor(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.draft:
        return const Color(0xFFF3F4F6);
      case QCReportStatus.waiting:
        return const Color(0xFFFFF4E5);
      case QCReportStatus.approved:
        return const Color(0xFFE8F7F1);
      case QCReportStatus.rejected:
      case QCReportStatus.needFollowUp:
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
        return 'Perlu Perbaikan';
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
