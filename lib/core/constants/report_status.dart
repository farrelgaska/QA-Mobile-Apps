enum ReportStatus {
  draft,
  waiting,
  approved,
  needsFix,
}

ReportStatus migrateLegacy(dynamic legacy) {
  if (legacy == null) return ReportStatus.draft;
  
  // If it's already a ReportStatus, return it
  if (legacy is ReportStatus) return legacy;

  final legacyStr = legacy.toString().toLowerCase().trim();
  
  if (legacyStr.contains('draft')) {
    return ReportStatus.draft;
  }
  
  if (legacyStr.contains('waiting') || 
      legacyStr.contains('menunggu') || 
      legacyStr.contains('pending') || 
      legacyStr.contains('onprogress') ||
      legacyStr.contains('on progress')) {
    return ReportStatus.waiting;
  }
  
  if (legacyStr.contains('approved') || 
      legacyStr.contains('disetujui') || 
      legacyStr.contains('lulus') || 
      legacyStr.contains('selesai') ||
      legacyStr.contains('pass') ||
      legacyStr.contains('aktif') ||
      legacyStr.contains('active')) {
    return ReportStatus.approved;
  }
  
  if (legacyStr.contains('needfollowup') || 
      legacyStr.contains('need_follow_up') || 
      legacyStr.contains('rejected') || 
      legacyStr.contains('perlubetulkan') || 
      legacyStr.contains('perluperbaikan') || 
      legacyStr.contains('tidak_sesuai') ||
      legacyStr.contains('tidak sesuai') ||
      legacyStr.contains('needsfix') ||
      legacyStr.contains('needs_fix') ||
      legacyStr.contains('revisi') ||
      legacyStr.contains('tindak lanjut') ||
      legacyStr.contains('perlu tindak lanjut') ||
      legacyStr.contains('perlu perbaikan')) {
    return ReportStatus.needsFix;
  }
  
  return ReportStatus.draft;
}
