import 'package:flutter/material.dart';
import '../../shared/models/enums.dart';
import 'status_helper.dart';

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
    if (status is ChecklistStatus) {
      return StatusStyle(
        background: StatusHelper.getChecklistStatusBgColor(status),
        foreground: StatusHelper.getChecklistStatusTextColor(status),
      );
    }
    if (status is String) {
      final lower = status.toLowerCase().trim();
      if (lower.startsWith('checkliststatus.')) {
        for (var val in ChecklistStatus.values) {
          if (val.toString().toLowerCase() == lower) {
            return StatusStyle(
              background: StatusHelper.getChecklistStatusBgColor(val),
              foreground: StatusHelper.getChecklistStatusTextColor(val),
            );
          }
        }
      }
    }

    final norm = StatusHelper.normalizeStatus(status);
    return StatusStyle(
      background: StatusHelper.getQCReportStatusBgColor(norm),
      foreground: StatusHelper.getQCReportStatusTextColor(norm),
    );
  }
}
