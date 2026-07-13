import type { ReportStatus, StandardResult, QCReport, SharedChecklistItem } from '../types/report';

export const STATUS_LABELS: Record<ReportStatus, string> = {
  DRAFT: 'Draft',
  SUBMITTED: 'Menunggu Review',
  NEEDS_FOLLOW_UP: 'Perlu Tindak Lanjut',
  APPROVED: 'Disetujui',
};

export const STATUS_BADGE_VARIANTS: Record<ReportStatus, 'gray' | 'yellow' | 'red' | 'green'> = {
  DRAFT: 'gray',
  SUBMITTED: 'yellow',
  NEEDS_FOLLOW_UP: 'red',
  APPROVED: 'green',
};

export const STATUS_COLORS: Record<ReportStatus, string> = {
  DRAFT: '#6B7280',
  SUBMITTED: '#F5A400',
  NEEDS_FOLLOW_UP: '#DC2626',
  APPROVED: '#16A765',
};

// Normalization function to handle legacy values
export function normalizeReportStatus(status: any): ReportStatus {
  if (!status) return 'DRAFT';
  const val = status.toString().toUpperCase().trim();
  if (val === 'DRAFT') return 'DRAFT';
  if (val === 'SUBMITTED' || val === 'WAITING' || val === 'MENUNGGU REVIEW' || val === 'MENUNGGU' || val === 'PENDING') {
    return 'SUBMITTED';
  }
  if (val === 'NEEDS_FOLLOW_UP' || val === 'NEEDFOLLOWUP' || val === 'NEED_FOLLOW_UP' || val === 'REVISION' || val === 'REVISI' || val === 'PERLU PERBAIKAN' || val === 'PERLU TINDAK LANJUT' || val === 'DITOLAK') {
    return 'NEEDS_FOLLOW_UP';
  }
  if (val === 'APPROVED' || val === 'DISETUJUI' || val === 'LULUS' || val === 'SELESAI') {
    return 'APPROVED';
  }
  return 'DRAFT';
}

export function getReportStatusLabel(status: ReportStatus): string {
  return STATUS_LABELS[status] || status;
}

export function getReportStatusBadgeVariant(status: ReportStatus): 'green' | 'yellow' | 'red' | 'gray' {
  return STATUS_BADGE_VARIANTS[status] || 'gray';
}

export function getStandardResultBadgeVariant(result: StandardResult): 'green' | 'yellow' | 'red' | 'gray' {
  switch (result) {
    case 'Lulus':
      return 'green';
    case 'Tidak Lulus':
      return 'red';
    case 'Perlu Review':
    default:
      return 'yellow';
  }
}

export function getStatusColor(status: ReportStatus): string {
  return STATUS_COLORS[status] || '#6B7280';
}

export function getStandardResultColor(result: StandardResult): string {
  switch (result) {
    case 'Lulus':
      return '#16A765';
    case 'Tidak Lulus':
      return '#DC2626';
    case 'Perlu Review':
    default:
      return '#F5A400';
  }
}


/** Map raw API conclusion / legacy strings → StandardResult union. */
export function normalizeStandardResult(raw?: string): StandardResult {
  if (!raw) return 'Perlu Review';
  const val = raw.toUpperCase().trim();
  if (val === 'PASSED' || val === 'PASS' || val === 'LULUS') return 'Lulus';
  if (val === 'NOT_PASSED' || val === 'FAIL' || val === 'FAILED' || val === 'TIDAK LULUS') return 'Tidak Lulus';
  return 'Perlu Review';
}

export function mapToSharedReport(report: any): QCReport {

  if (!report) return report;
  
  const staff = report.staff || {
    name: report.submittedBy || report.checkedByName || 'Yanuar Luthfi',
    nik: report.submittedByNik || report.checkedByNik || report.createdByNik || 'NIK-908271',
  };
  
  const location = report.location || {
    site_id: report.siteId || 'site-1',
    site_name: report.siteName || report.locationName || 'Bekasi Site',
    area: report.area || 'Sektor Utama',
    detail_location: report.detailLocation || report.locationName || 'Bekasi Site',
  };
  
  const type = (report.type === 'material' || report.type === 'MATERIAL') ? 'material' : 'pekerjaan';
  const status = normalizeReportStatus(report.status);
  
  const rawItems = report.checklist_items || report.checklistItems || report.checklistAnswers || report.checklistResults || [];
  const checklist_items: SharedChecklistItem[] = rawItems.map((item: any) => {
    let evaluation: 'PASS' | 'FAIL' | 'NEEDS_REVIEW' = 'NEEDS_REVIEW';
    const rawEvalUpper = (item.admin_evaluation || '').toUpperCase();
    if (rawEvalUpper === 'PASS') {
      evaluation = 'PASS';
    } else if (rawEvalUpper === 'FAIL') {
      evaluation = 'FAIL';
    } else if (
      rawEvalUpper === 'NEEDS_REVIEW' ||
      rawEvalUpper === 'PENDING' ||
      rawEvalUpper === '' ||
      !rawEvalUpper
    ) {
      // Mobile always sends NEEDS_REVIEW — Admin has not evaluated yet.
      evaluation = 'NEEDS_REVIEW';
    } else if (status === 'APPROVED' || status === 'NEEDS_FOLLOW_UP') {
      // Legacy: derive from old result/status field for already-reviewed reports
      const legacyEval = item.result || item.status;
      if (legacyEval === 'pass' || legacyEval === 'PASS' || legacyEval === 'lulus') {
        evaluation = 'PASS';
      } else if (legacyEval === 'fail' || legacyEval === 'FAIL' || legacyEval === 'tidakSesuai') {
        evaluation = 'FAIL';
      }
    }
    
    return {
      id: item.id || item.itemId || '',
      parameter_name: item.parameter_name || item.name || item.paramName || '',
      input_type: item.input_type || item.inputType || 'text',
      standard_text: item.standard_text || item.standardLabel || item.standardText || item.standard || '',
      unit: item.unit || '',
      actual_value: item.actual_value || item.actualValue || item.resultValue || (item.value !== undefined ? item.value.toString() : ''),
      staff_note: item.staff_note || item.issueNote || item.staffNote || '',
      item_photos: item.item_photos || item.photoUrls || item.photoPaths || item.photos || [],
      admin_evaluation: evaluation,
      admin_note: item.admin_note || item.adminNote || '',
    };
  });
  
  const admin_review = report.admin_review || {
    admin_note: report.adminNote || '',
    conclusion: report.standardResult || 'Perlu Review',
    reviewed_at: report.reviewedAt || '',
  };
  
  return {
    id: report.id,
    type,
    title: report.title,
    status,
    staff_note: report.staff_note || report.staffNote || '',
    general_photos: report.general_photos || report.photos || [],
    revision_number: report.revision_number || report.revisionNumber || 1,
    revision_history: (report.revision_history || report.revisionHistory || []).map((h: any) => mapToSharedReport(h)),
    
    template_id: report.template_id || '',
    // Note: form_code and template_id are distinct — do not conflate them
    form_code: report.form_code || report.formCode || '',
    staff,
    location,
    general_info: report.general_info || report.generalInfo || {},
    checklist_items,
    submitted_at: report.submitted_at || report.submittedAt || report.date || new Date().toISOString(),
    admin_review,
    
    // Legacy mapping compatibility
    submittedBy: staff.name,
    submittedByNik: staff.nik,
    submittedAt: report.submitted_at || report.submittedAt || report.date || new Date().toISOString(),
    locationName: location.detail_location || location.site_name,
    checklistItems: checklist_items.map(item => ({
      id: item.id,
      name: item.parameter_name,
      standardLabel: item.standard_text,
      actualValue: item.actual_value,
      unit: item.unit,
      // Map admin_evaluation to legacy ChecklistResult; NEEDS_REVIEW for any unevaluated item
      result: item.admin_evaluation === 'PASS' ? 'PASS' : item.admin_evaluation === 'FAIL' ? 'FAIL' : 'NEEDS_REVIEW',
      photoUrls: item.item_photos,
      adminNote: item.admin_note,
    })),
    photos: report.general_photos || report.photos || [],
    adminNote: admin_review.admin_note || report.adminNote || '',
    standardResult: normalizeStandardResult(admin_review.conclusion || report.standardResult),
  };
}
