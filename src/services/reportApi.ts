/**
 * reportApi.ts
 * Thin typed wrapper around the prototype backend at http://localhost:3002.
 * All functions throw on non-2xx responses so callers can handle errors.
 */

// Prototype backend URL (configured to port 3002)
const BASE_URL = 'http://localhost:3002';

// ─── Raw API shape (shared report contract) ──────────────────────────────────

export interface ApiChecklistItem {
  id: string;
  parameter_name: string;
  input_type: string;
  standard_text: string;
  unit?: string;
  actual_value: string;
  staff_note?: string;
  item_photos: string[];
  admin_evaluation: 'PASS' | 'FAIL' | 'NEEDS_REVIEW' | 'PENDING';
  admin_note?: string;
}

export interface ApiReport {
  id: string;
  type: 'MATERIAL' | 'WORK' | 'material' | 'pekerjaan';
  templateId?: string;
  formCode?: string;
  title: string;
  status: 'DRAFT' | 'SUBMITTED' | 'NEEDS_FOLLOW_UP' | 'APPROVED';
  staff?: { name: string; nik: string };
  location?: {
    site_id: string;
    site_name: string;
    area: string;
    detail_location: string;
  };
  general_info?: Record<string, string>;
  checklist_items?: ApiChecklistItem[];
  staff_note?: string;
  submitted_at?: string;
  revision_number?: number;
  admin_review?: {
    admin_note?: string;
    reviewed_at?: string;
    reviewed_by?: string;
    /** PASSED for approved; NOT_PASSED for follow-up */
    conclusion?: string;
  };
  general_photos?: string[];
}

// ─── API helpers ─────────────────────────────────────────────────────────────

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options?.headers ?? {}),
    },
  });

  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(`API ${res.status}: ${text}`);
  }

  return res.json() as Promise<T>;
}

// ─── Public API ──────────────────────────────────────────────────────────────

/** Fetch all reports. Admin sees SUBMITTED, NEEDS_FOLLOW_UP and APPROVED — not DRAFT. */
export async function fetchReports(): Promise<ApiReport[]> {
  const all = await request<ApiReport[]>('/reports');
  return all.filter(r => r.status !== 'DRAFT');
}

/** Fetch a single report by ID. */
export async function fetchReport(id: string): Promise<ApiReport> {
  return request<ApiReport>(`/reports/${id}`);
}

/** PATCH report — used for approve and request follow-up actions. */
export async function patchReport(id: string, patch: Partial<ApiReport>): Promise<ApiReport> {
  return request<ApiReport>(`/reports/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
}

/**
 * Approve a report: sets status → APPROVED and stores admin_review.
 */
export async function approveReportApi(
  id: string,
  adminNote: string,
  reviewedBy: string,
  updatedChecklistItems?: ApiChecklistItem[]
): Promise<ApiReport> {
  const patch: Partial<ApiReport> = {
    status: 'APPROVED',
    admin_review: {
      admin_note: adminNote || 'Laporan disetujui. Semua kriteria memenuhi standar teknis.',
      conclusion: 'PASSED',
      reviewed_at: new Date().toISOString(),
      reviewed_by: reviewedBy,
    },
    ...(updatedChecklistItems ? { checklist_items: updatedChecklistItems } : {}),
  };
  return patchReport(id, patch);
}

/**
 * Request follow-up: sets status → NEEDS_FOLLOW_UP and stores admin_review.
 */
export async function requestFollowUpApi(
  id: string,
  adminNote: string,
  reviewedBy: string,
  updatedChecklistItems?: ApiChecklistItem[]
): Promise<ApiReport> {
  const patch: Partial<ApiReport> = {
    status: 'NEEDS_FOLLOW_UP',
    admin_review: {
      admin_note: adminNote,
      conclusion: 'NOT_PASSED',
      reviewed_at: new Date().toISOString(),
      reviewed_by: reviewedBy,
    },
    ...(updatedChecklistItems ? { checklist_items: updatedChecklistItems } : {}),
  };
  return patchReport(id, patch);
}

// ─── QC Templates API ─────────────────────────────────────────────────────────

export interface ApiTemplateChecklistItem {
  id: string;
  parameter_name: string;
  input_type: string;
  standard_text: string;
  unit?: string;
  is_required: boolean;
  name?: string;
  standardLabel?: string;
  minVal?: number;
  maxVal?: number;
  requiredPhoto?: boolean;
  isActive?: boolean;
}

export interface ApiTemplate {
  id: string;
  type: 'MATERIAL' | 'WORK';
  name: string;
  formCode: string;
  category: string;
  standardCode: string;
  checklistItems: ApiTemplateChecklistItem[];
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
  segment?: 'provisioning' | 'assurance' | 'construction';
}

export async function fetchTemplates(): Promise<ApiTemplate[]> {
  return request<ApiTemplate[]>('/templates');
}

export async function fetchTemplate(id: string): Promise<ApiTemplate> {
  return request<ApiTemplate>(`/templates/${id}`);
}

export async function postTemplate(template: ApiTemplate): Promise<ApiTemplate> {
  return request<ApiTemplate>('/templates', {
    method: 'POST',
    body: JSON.stringify(template),
  });
}

export async function patchTemplate(id: string, patch: Partial<ApiTemplate>): Promise<ApiTemplate> {
  return request<ApiTemplate>(`/templates/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
}

export async function deleteTemplateChecklistItem(templateId: string, itemId: string): Promise<ApiTemplate> {
  return request<ApiTemplate>(`/templates/${templateId}/items/${itemId}`, {
    method: 'DELETE',
  });
}

