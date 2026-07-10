export type ReportStatus = 'Draft' | 'Menunggu Review' | 'Disetujui' | 'Perlu Perbaikan';

export type ReportType = 'material' | 'pekerjaan';

export type StandardResult = 'Lulus' | 'Tidak Lulus' | 'Perlu Review';

export type ChecklistResult = 'pass' | 'fail' | 'review';

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

export interface QCReport {
  id: string;
  type: ReportType;
  title: string;
  locationName: string;
  submittedBy: string;
  submittedByNik: string;
  submittedAt: string;
  status: ReportStatus;
  standardResult: StandardResult;
  checklistItems: ChecklistItem[];
  photos: string[];
  adminNote?: string;
}
