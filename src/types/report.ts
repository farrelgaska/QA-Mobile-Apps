export type ReportStatus = 'DRAFT' | 'SUBMITTED' | 'NEEDS_FOLLOW_UP' | 'APPROVED';

export type ReportType = 'material' | 'pekerjaan';

export type StandardResult = 'Lulus' | 'Tidak Lulus' | 'Perlu Review';

export type ChecklistResult = 'PASS' | 'FAIL' | 'NEEDS_REVIEW';

export type ParameterEvaluationStatus =
  | 'NOT_EVALUATED'
  | 'WITHIN_STANDARD'
  | 'OUT_OF_STANDARD';

export type SampleInspectionStatus = 'NOT_STARTED' | 'IN_PROGRESS' | 'COMPLETED';

export interface QCEvidenceCaptureMetadataEntry {
  capturedAt: string | null;
  latitude: number | null;
  longitude: number | null;
  accuracyMeters: number | null;
  locationLabel: string | null;
  serverReceivedAt: string | null;
}

export type QCEvidenceCaptureMetadata =
  Record<string, QCEvidenceCaptureMetadataEntry>;

export interface ReportGeneralInfo {
  qcEvidenceCaptureMetadata?: QCEvidenceCaptureMetadata | null;
  qcSampleEvaluationStatuses?: string;
  qcSamplingFailedSampleNumbers?: string;
  qcSamplingDecision?: string;
  qcSamplingStopReason?: string;
  poNumber?: string;
  poDate?: string;
  doNumber?: string;
  vendorName?: string;
  materialId?: string;
  brandName?: string;
  warehouseLocation?: string;
  arrivalVolume?: string;
  samplingVolume?: string;
  tkdnNumber?: string;
  tkdnCertDate?: string;
  tkdnValue?: string;
  stelVersion?: string;
  qaExpiryDate?: string;
  [key: string]: unknown;
}

export interface SampleChecklistAnswer {
  checklist_item_id: string;
  input_type: 'number' | 'text' | 'choice' | 'boolean';
  actual_value: string | number | boolean | null;
  note: string;
  photo_paths: string[];
  standard_text: string;
  standard_value: number | null;
  unit: string;
  upper_tolerance: number | null;
  lower_tolerance: number | null;
  minimum_value: number | null;
  maximum_value: number | null;
  evaluation_status: ParameterEvaluationStatus;
  /** Admin-only review scoped by sample ID + checklist item ID. */
  admin_evaluation?: ChecklistResult;
  admin_note?: string;
}

export interface ReportSample {
  id: string;
  sample_number: number;
  inspection_status: SampleInspectionStatus;
  checklist_answers: SampleChecklistAnswer[];
  notes: string;
  photo_paths: string[];
  created_at: string;
  updated_at: string;
}

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
  /** Admin-only evaluation. Mobile always sends NEEDS_REVIEW; Admin sets PASS or FAIL. */
  admin_evaluation: 'PASS' | 'FAIL' | 'NEEDS_REVIEW';
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
  general_info?: ReportGeneralInfo;
  checklist_items?: SharedChecklistItem[];
  sample_count?: number;
  samples?: ReportSample[];
  /** Canonical object_path -> temporary display URL. Never serialized to PATCH. */
  evidenceDisplayUrls?: Record<string, string>;
  review_requested?: boolean;
  review_requested_at?: string | null;
  review_requested_by_role?: string | null;
  review_failed_sample_count?: number | null;
  review_failed_sample_ids?: string[];
  review_failed_sample_numbers?: number[];
  submitted_at?: string;
  admin_review?: {
    admin_note?: string;
    reviewed_at?: string;
    reviewed_by?: string;
    /** PASSED | NOT_PASSED — set by Admin on final decision. */
    conclusion?: 'PASSED' | 'NOT_PASSED' | string;
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
