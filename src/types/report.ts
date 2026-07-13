export type ReportStatus = 'DRAFT' | 'SUBMITTED' | 'NEEDS_FOLLOW_UP' | 'APPROVED';

export type ReportType = 'material' | 'pekerjaan';

export type StandardResult = 'Lulus' | 'Tidak Lulus' | 'Perlu Review';

export type ChecklistResult = 'PASS' | 'FAIL' | 'NEEDS_REVIEW';

export interface ChecklistItem {
  id: string;
  name: string;
  standardLabel: string;
  actualValue: string;
  unit?: string;
  result: ChecklistResult;
  photoUrls: string[];
  adminNote?: string;
}

export interface SharedChecklistItem {
  id: string;
  parameter_name: string;
  input_type: string;
  standard_text: string;
  unit?: string;
  actual_value: string;
  staff_note?: string;
  item_photos: string[];
  admin_evaluation: 'PASS' | 'FAIL' | 'PENDING';
  admin_note?: string;
}

export interface QCReport {
  id: string;
  type: ReportType; // maps internally to QCType
  title: string;
  status: ReportStatus;
  staff_note?: string;
  general_photos?: string[];
  revision_number?: number;
  revision_history?: QCReport[];

  // Shared Contract Fields
  template_id?: string;
  form_code?: string;
  staff?: {
    name: string;
    nik: string;
  };
  location?: {
    site_id: string;
    site_name: string;
    area: string;
    detail_location: string;
  };
  general_info?: Record<string, string>;
  checklist_items?: SharedChecklistItem[];
  submitted_at?: string;
  admin_review?: {
    admin_note?: string;
    reviewed_at?: string;
    conclusion?: string;
  };

  // Legacy Fields for Backward Compatibility
  locationName: string;
  submittedBy: string;
  submittedByNik: string;
  submittedAt: string;
  standardResult: StandardResult;
  checklistItems: ChecklistItem[];
  photos: string[];
  adminNote?: string;
}
