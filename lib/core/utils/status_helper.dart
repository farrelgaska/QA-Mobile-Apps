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
        return 'Menunggu';
      case ReportStatus.disetujui:
        return 'Disetujui';
      case ReportStatus.ditolak:
        return 'Pending';
      case ReportStatus.revisi:
      case ReportStatus.perluTindakLanjut:
        return 'Perlu Perbaikan';
    }
  }

  static Color getReportStatusTextColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return AppColors.inactiveText;
      case ReportStatus.menunggu:
        return AppColors.waitingText;
      case ReportStatus.disetujui:
        return AppColors.approvedText;
      case ReportStatus.ditolak:
        return const Color(0xFFF59E0B); // Pending Orange
      case ReportStatus.revisi:
      case ReportStatus.perluTindakLanjut:
        return AppColors.rejectedText; // Merah pastel
    }
  }

  static Color getReportStatusBgColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return AppColors.inactiveBg;
      case ReportStatus.menunggu:
        return AppColors.waitingBg;
      case ReportStatus.disetujui:
        return AppColors.approvedBg;
      case ReportStatus.ditolak:
        return const Color(0xFFFFF4E5); // Pending Orange Soft
      case ReportStatus.revisi:
      case ReportStatus.perluTindakLanjut:
        return AppColors.rejectedBg; // Merah pastel
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
        return 'Tidak Sesuai';
      case ChecklistStatus.perluTindakLanjut:
        return 'Perlu Perbaikan';
    }
  }

  static Color getChecklistStatusTextColor(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.belumDiisi:
        return AppColors.inactiveText;
      case ChecklistStatus.lulus:
        return AppColors.approvedText;
      case ChecklistStatus.tidakSesuai:
      case ChecklistStatus.perluTindakLanjut:
        return AppColors.rejectedText;
    }
  }

  static Color getChecklistStatusBgColor(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.belumDiisi:
        return AppColors.inactiveBg;
      case ChecklistStatus.lulus:
        return AppColors.approvedBg;
      case ChecklistStatus.tidakSesuai:
      case ChecklistStatus.perluTindakLanjut:
        return AppColors.rejectedBg;
    }
  }

  // --- QCReportStatus (New) helpers ---
  static String getQCReportStatusLabel(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.draft:
        return 'Draft';
      case QCReportStatus.waiting:
        return 'Menunggu';
      case QCReportStatus.approved:
        return 'Disetujui';
      case QCReportStatus.rejected:
        return 'Pending';
      case QCReportStatus.needFollowUp:
        return 'Perlu Perbaikan';
    }
  }

  static Color getQCReportStatusTextColor(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.draft:
        return AppColors.inactiveText;
      case QCReportStatus.waiting:
        return AppColors.waitingText;
      case QCReportStatus.approved:
        return AppColors.approvedText;
      case QCReportStatus.rejected:
        return const Color(0xFFF59E0B); // Pending Orange
      case QCReportStatus.needFollowUp:
        return AppColors.rejectedText; // Merah pastel
    }
  }

  static Color getQCReportStatusBgColor(QCReportStatus status) {
    switch (status) {
      case QCReportStatus.draft:
        return AppColors.inactiveBg;
      case QCReportStatus.waiting:
        return AppColors.waitingBg;
      case QCReportStatus.approved:
        return AppColors.approvedBg;
      case QCReportStatus.rejected:
        return const Color(0xFFFFF4E5); // Pending Orange Soft
      case QCReportStatus.needFollowUp:
        return AppColors.rejectedBg; // Merah pastel
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
