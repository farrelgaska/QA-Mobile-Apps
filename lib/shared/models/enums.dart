enum ReportStatus {
  draft,
  menunggu,
  disetujui,
  revisi, // Kept for backward compatibility but mapped to 'Perlu Tindak Lanjut'
  ditolak,
  perluTindakLanjut
}

enum ChecklistStatus {
  belumDiisi,
  lulus,
  tidakSesuai,
  perluTindakLanjut
}

enum QCType {
  material,
  pekerjaan
}

enum InputType {
  number,
  text,
  choice
}

enum WorkSegment {
  provisioning,
  assurance,
  construction
}

// User-requested dynamic QC enums
enum QCInputType {
  number,
  text,
  booleanCheck,
  choice,
  photo
}

enum QCValidationType {
  none,
  range,
  min,
  max,
  exact,
  booleanRequired
}

enum QCResultStatus {
  notFilled,
  pass,
  fail,
  needFollowUp
}

enum QCReportStatus {
  draft,
  waiting,
  approved,
  needFollowUp,
}
