/**
 * reportApi.ts
 * Thin typed wrapper around the configured backend API.
 * All functions throw on non-2xx responses so callers can handle errors.
 */

const BASE_URL = (import.meta.env.VITE_API_BASE_URL?.trim() || 'http://localhost:3002')
  .replace(/\/+$/, '');

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

export interface QCEvidenceSignedUrl {
  object_path: string;
  signed_url: string;
  expires_in: number;
}

interface QCEvidenceSignedUrlsResponse {
  signed_urls: QCEvidenceSignedUrl[];
  expires_in: number;
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

function isPrivateEvidencePath(value: string): boolean {
  return !/^(?:https?:|blob:|data:)/i.test(value)
    && !value.startsWith('/')
    && !value.startsWith('asset:')
    && !value.startsWith('assets/');
}

/** Resolve private QC evidence paths without altering their persisted values. */
export async function resolveQCEvidenceSignedUrls(
  paths: string[]
): Promise<Record<string, string>> {
  const privatePaths = [...new Set(paths.filter(isPrivateEvidencePath))];
  const resolved: Record<string, string> = {};

  for (let start = 0; start < privatePaths.length; start += 50) {
    const response = await request<QCEvidenceSignedUrlsResponse>(
      '/uploads/qc-evidence/signed-urls',
      {
        method: 'POST',
        body: JSON.stringify({ paths: privatePaths.slice(start, start + 50) }),
      }
    );
    response.signed_urls.forEach(entry => {
      resolved[entry.object_path] = entry.signed_url;
    });
  }

  return resolved;
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

export type TemplateInputType = 'number' | 'text' | 'choice';
export type TemplateChoiceOutcome = 'PASS' | 'FAIL';

export interface ApiTemplateChoiceOption {
  id: string;
  label: string;
  value: string;
  outcome: TemplateChoiceOutcome;
  position: number;
}

export interface ApiTemplateChecklistItem {
  id: string;
  parameterName: string;
  inputType: TemplateInputType;
  standardText: string;
  minValue: number | null;
  maxValue: number | null;
  unit: string | null;
  choiceOptions: ApiTemplateChoiceOption[];
  choices: string[];
  isRequired: boolean;
  requiredPhoto: boolean;
  isActive: boolean;
  isCritical: boolean;
  position: number;
  category?: string;
}

export interface ApiTemplateChecklistItemWire {
  id: string;
  parameter_name: string;
  input_type: TemplateInputType;
  standard_text: string;
  min_value: number | null;
  max_value: number | null;
  unit: string | null;
  choice_options: ApiTemplateChoiceOption[];
  choices?: string[];
  is_required: boolean;
  required_photo: boolean;
  is_active: boolean;
  is_critical: boolean;
  position: number;
  category?: string;
}

export interface ApiTemplateWire {
  id: string;
  type: 'MATERIAL' | 'WORK';
  name: string;
  description?: string;
  form_code: string;
  category: string;
  standard_code: string;
  checklist_items: ApiTemplateChecklistItemWire[];
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
  segment?: 'provisioning' | 'assurance' | 'construction';
}

export interface ApiTemplateChecklistItemWrite {
  id: string;
  parameterName: string;
  inputType: TemplateInputType;
  standardText: string;
  minVal?: number;
  maxVal?: number;
  minValue?: number | null;
  maxValue?: number | null;
  unit?: string | null;
  choiceOptions?: ApiTemplateChoiceOption[];
  choices?: string[];
  isRequired: boolean;
  requiredPhoto: boolean;
  isActive?: boolean;
  isCritical?: boolean;
  position?: number;
  category?: string;
}

export interface ApiTemplate {
  id: string;
  type: 'MATERIAL' | 'WORK';
  name: string;
  description?: string;
  formCode: string;
  category: string;
  standardCode: string;
  checklistItems: ApiTemplateChecklistItem[];
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
  segment?: 'provisioning' | 'assurance' | 'construction';
}

export type ApiTemplateWrite = Omit<ApiTemplate, 'checklistItems'> & {
  checklistItems: ApiTemplateChecklistItemWrite[];
};

export type ApiTemplatePatch = Partial<Omit<ApiTemplateWrite, 'id' | 'type' | 'checklistItems'>> & {
  checklistItems?: ApiTemplateChecklistItemWrite[];
};

const requireBoolean = (value: boolean, field: string): boolean => {
  if (typeof value !== 'boolean') throw new Error(`Invalid template response: ${field} must be boolean`);
  return value;
};

export const normalizeTemplateChecklistItem = (
  item: ApiTemplateChecklistItemWire
): ApiTemplateChecklistItem => ({
  id: item.id,
  parameterName: item.parameter_name,
  inputType: item.input_type,
  standardText: String(item.standard_text ?? ''),
  minValue: item.min_value ?? null,
  maxValue: item.max_value ?? null,
  unit: item.unit ?? null,
  choiceOptions: item.choice_options ?? [],
  choices: item.choices ?? [],
  isRequired: requireBoolean(item.is_required, 'checklist_items[].is_required'),
  requiredPhoto: requireBoolean(item.required_photo, 'checklist_items[].required_photo'),
  isActive: requireBoolean(item.is_active, 'checklist_items[].is_active'),
  isCritical: requireBoolean(item.is_critical, 'checklist_items[].is_critical'),
  position: item.position,
  category: item.category,
});

export const normalizeTemplate = (template: ApiTemplateWire): ApiTemplate => ({
  id: template.id,
  type: template.type,
  name: template.name,
  description: template.description,
  formCode: template.form_code,
  category: template.category,
  standardCode: template.standard_code,
  checklistItems: (template.checklist_items ?? []).map(normalizeTemplateChecklistItem),
  isActive: requireBoolean(template.is_active, 'is_active'),
  createdAt: template.created_at,
  updatedAt: template.updated_at,
  segment: template.segment,
});

export const serializeTemplateChecklistItem = (
  item: ApiTemplateChecklistItemWrite,
  index: number
): ApiTemplateChecklistItemWire => ({
  id: item.id,
  parameter_name: item.parameterName,
  input_type: item.inputType,
  standard_text: String(item.standardText ?? ''),
  min_value: item.minValue ?? item.minVal ?? null,
  max_value: item.maxValue ?? item.maxVal ?? null,
  unit: item.unit ?? null,
  choice_options: item.choiceOptions ?? [],
  choices: item.choices ?? [],
  is_required: item.isRequired,
  required_photo: item.requiredPhoto,
  is_active: item.isActive ?? true,
  is_critical: item.isCritical ?? false,
  position: item.position ?? index,
  category: item.category,
});

export type ApiTemplateChecklistItemMutation = Omit<ApiTemplateChecklistItemWrite, 'id'> & {
  id?: string;
};

const serializeTemplateChecklistItemMutation = (
  item: ApiTemplateChecklistItemMutation
): Partial<ApiTemplateChecklistItemWire> => {
  const wire = serializeTemplateChecklistItem(
    { ...item, id: item.id ?? '' },
    item.position ?? 0
  );
  if (item.id === undefined) delete (wire as Partial<ApiTemplateChecklistItemWire>).id;
  if (item.position === undefined) delete (wire as Partial<ApiTemplateChecklistItemWire>).position;
  return wire;
};

export const serializeTemplateChecklistItemPatch = (
  patch: Partial<ApiTemplateChecklistItemMutation>
): Partial<ApiTemplateChecklistItemWire> => {
  const wire: Partial<ApiTemplateChecklistItemWire> = {};
  if (patch.parameterName !== undefined) wire.parameter_name = patch.parameterName;
  if (patch.inputType !== undefined) wire.input_type = patch.inputType;
  if (patch.standardText !== undefined) wire.standard_text = String(patch.standardText);
  if (patch.minValue !== undefined) wire.min_value = patch.minValue;
  if (patch.maxValue !== undefined) wire.max_value = patch.maxValue;
  if (patch.unit !== undefined) wire.unit = patch.unit;
  if (patch.choiceOptions !== undefined) wire.choice_options = patch.choiceOptions;
  if (patch.choices !== undefined) wire.choices = patch.choices;
  if (patch.isRequired !== undefined) wire.is_required = patch.isRequired;
  if (patch.requiredPhoto !== undefined) wire.required_photo = patch.requiredPhoto;
  if (patch.isActive !== undefined) wire.is_active = patch.isActive;
  if (patch.isCritical !== undefined) wire.is_critical = patch.isCritical;
  if (patch.position !== undefined) wire.position = patch.position;
  if (patch.category !== undefined) wire.category = patch.category;
  return wire;
};

export const serializeTemplate = (template: ApiTemplateWrite): ApiTemplateWire => ({
  id: template.id,
  type: template.type,
  name: template.name,
  description: template.description,
  form_code: template.formCode,
  category: template.category,
  standard_code: template.standardCode,
  checklist_items: template.checklistItems.map(serializeTemplateChecklistItem),
  is_active: template.isActive,
  created_at: template.createdAt,
  updated_at: template.updatedAt,
  segment: template.segment,
});

export const serializeTemplatePatch = (patch: ApiTemplatePatch): Partial<ApiTemplateWire> => {
  const wire: Partial<ApiTemplateWire> = {};
  if (patch.name !== undefined) wire.name = patch.name;
  if (patch.description !== undefined) wire.description = patch.description;
  if (patch.formCode !== undefined) wire.form_code = patch.formCode;
  if (patch.category !== undefined) wire.category = patch.category;
  if (patch.standardCode !== undefined) wire.standard_code = patch.standardCode;
  if (patch.isActive !== undefined) wire.is_active = patch.isActive;
  if (patch.createdAt !== undefined) wire.created_at = patch.createdAt;
  if (patch.updatedAt !== undefined) wire.updated_at = patch.updatedAt;
  if (patch.segment !== undefined) wire.segment = patch.segment;
  if (patch.checklistItems !== undefined) {
    wire.checklist_items = patch.checklistItems.map(serializeTemplateChecklistItem);
  }
  return wire;
};

export async function fetchTemplates(): Promise<ApiTemplate[]> {
  const templates = await request<ApiTemplateWire[]>('/templates');
  return templates.map(normalizeTemplate);
}

export async function fetchTemplate(id: string): Promise<ApiTemplate> {
  return normalizeTemplate(await request<ApiTemplateWire>(`/templates/${id}`));
}

export async function postTemplate(template: ApiTemplateWrite): Promise<ApiTemplate> {
  const created = await request<ApiTemplateWire>('/templates', {
    method: 'POST',
    body: JSON.stringify(serializeTemplate(template)),
  });
  return normalizeTemplate(created);
}

export async function patchTemplate(id: string, patch: ApiTemplatePatch): Promise<ApiTemplate> {
  const updated = await request<ApiTemplateWire>(`/templates/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(serializeTemplatePatch(patch)),
  });
  return normalizeTemplate(updated);
}

export async function deleteTemplateChecklistItem(templateId: string, itemId: string): Promise<ApiTemplate> {
  await request<ApiTemplateWire>(`/templates/${templateId}/items/${itemId}`, {
    method: 'DELETE',
  });
  return fetchTemplate(templateId);
}

export async function postTemplateChecklistItem(
  templateId: string,
  item: ApiTemplateChecklistItemMutation
): Promise<ApiTemplateChecklistItem> {
  const created = await request<ApiTemplateChecklistItemWire>(`/templates/${templateId}/items`, {
    method: 'POST',
    body: JSON.stringify(serializeTemplateChecklistItemMutation(item)),
  });
  return normalizeTemplateChecklistItem(created);
}

export async function patchTemplateChecklistItem(
  templateId: string,
  itemId: string,
  patch: Partial<ApiTemplateChecklistItemMutation>
): Promise<ApiTemplateChecklistItem> {
  const updated = await request<ApiTemplateChecklistItemWire>(`/templates/${templateId}/items/${itemId}`, {
    method: 'PATCH',
    body: JSON.stringify(serializeTemplateChecklistItemPatch(patch)),
  });
  return normalizeTemplateChecklistItem(updated);
}
