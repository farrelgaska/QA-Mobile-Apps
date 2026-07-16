const { templateSchema } = require('../../contracts/template.contract');

const toIso = value => value instanceof Date ? value.toISOString() : value;
const valueOf = (object, canonical, legacy, fallback) => {
  if (object?.[canonical] !== undefined) return object[canonical];
  if (legacy && object?.[legacy] !== undefined) return object[legacy];
  return fallback;
};
const nullableNumber = value => value === undefined || value === null || value === '' ? null : Number(value);

const mapTemplateItemRow = row => ({
  id: row.id,
  parameter_name: row.parameter_name,
  input_type: row.input_type,
  standard_text: row.standard_text ?? '',
  min_value: nullableNumber(row.min_value),
  max_value: nullableNumber(row.max_value),
  unit: row.unit || null,
  is_required: row.is_required,
  required_photo: row.required_photo,
  is_active: row.is_active,
  is_critical: row.is_critical,
  position: row.position,
  choices: row.choices || [],
  choice_options: row.choice_options || [],
  category: row.category,
  validation_rule: row.validation_type === null
    && row.validation_min_value === null
    && row.validation_max_value === null
    && row.validation_exact_value === null
    ? null
    : {
        type: row.validation_type,
        min_value: row.validation_min_value === null ? null : Number(row.validation_min_value),
        max_value: row.validation_max_value === null ? null : Number(row.validation_max_value),
        exact_value: row.validation_exact_value
      },
  ...(row.migration_metadata ? { migration_metadata: row.migration_metadata } : {})
});

const mapTemplateAggregate = (row, itemRows = []) => ({
  id: row.id,
  type: row.type,
  name: row.name,
  description: row.description,
  form_code: row.form_code,
  category: row.category,
  segment: row.segment,
  standard_code: row.standard_code,
  is_active: row.is_active,
  ...(row.workflow_status ? { workflow_status: row.workflow_status } : {}),
  version: row.version,
  created_at: toIso(row.created_at),
  updated_at: toIso(row.updated_at),
  checklist_items: itemRows.map(mapTemplateItemRow),
  ...(row.migration_metadata ? { migration_metadata: row.migration_metadata } : {})
});

const mapReportItemRow = (row, attachmentRows = []) => ({
  id: row.id,
  parameter_name: row.parameter_name,
  input_type: row.input_type,
  standard_text: row.standard_text,
  unit: row.unit,
  actual_value: row.actual_value,
  staff_note: row.staff_note,
  item_photos: attachmentRows.map(attachment => attachment.uri),
  admin_evaluation: row.admin_evaluation,
  admin_note: row.admin_note
});

const mapReportAggregate = (row, itemRows = [], reviewRow = null, attachmentRows = []) => {
  const itemAttachments = new Map();
  const generalPhotos = [];
  for (const attachment of attachmentRows) {
    if (attachment.attachment_scope === 'GENERAL') generalPhotos.push(attachment.uri);
    else {
      const list = itemAttachments.get(attachment.report_item_id) || [];
      list.push(attachment);
      itemAttachments.set(attachment.report_item_id, list);
    }
  }

  return {
    id: row.id,
    type: row.type,
    template_id: row.template_id || '',
    form_code: row.form_code,
    title: row.title,
    status: row.status,
    staff: { name: row.staff_name, nik: row.staff_nik },
    location: {
      site_id: row.site_id,
      site_name: row.site_name,
      area: row.area,
      detail_location: row.detail_location
    },
    general_info: row.general_info || {},
    checklist_items: itemRows.map(item => mapReportItemRow(item, itemAttachments.get(item.id) || [])),
    staff_note: row.staff_note,
    submitted_at: toIso(row.submitted_at),
    admin_review: reviewRow ? {
      admin_note: reviewRow.admin_note,
      conclusion: reviewRow.conclusion,
      reviewed_at: toIso(reviewRow.reviewed_at),
      reviewed_by: reviewRow.reviewed_by
    } : null,
    general_photos: generalPhotos,
    revision_number: row.revision_number,
    ...(row.migration_metadata ? { migration_metadata: row.migration_metadata } : {})
  };
};

const canonicalTemplateShape = template => ({
  id: template.id,
  type: template.type || 'MATERIAL',
  name: template.name || '',
  description: template.description || '',
  form_code: valueOf(template, 'form_code', 'formCode', ''),
  category: template.category || '',
  segment: template.segment || 'construction',
  standard_code: valueOf(template, 'standard_code', 'standardCode', ''),
  is_active: valueOf(template, 'is_active', 'isActive', true),
  workflow_status: valueOf(template, 'workflow_status', 'workflowStatus', null),
  version: template.version ?? 1,
  created_at: valueOf(template, 'created_at', 'createdAt', new Date().toISOString()),
  updated_at: valueOf(template, 'updated_at', 'updatedAt', new Date().toISOString()),
  checklist_items: valueOf(template, 'checklist_items', 'checklistItems', []).map((item, index) => {
    const rule = valueOf(item, 'validation_rule', 'validationRule', null);
    return {
      id: item.id,
      parameter_name: valueOf(item, 'parameter_name', 'parameterName', item.name || ''),
      input_type: valueOf(item, 'input_type', 'inputType', 'text'),
      standard_text: String(valueOf(item, 'standard_text', 'standardText', item.standardLabel || '') ?? ''),
      min_value: nullableNumber(valueOf(item, 'min_value', 'minValue', item.minVal)),
      max_value: nullableNumber(valueOf(item, 'max_value', 'maxValue', item.maxVal)),
      unit: item.unit === undefined || item.unit === '' ? null : item.unit,
      is_required: valueOf(item, 'is_required', 'required', false),
      required_photo: valueOf(item, 'required_photo', 'requiredPhoto', false),
      is_active: valueOf(item, 'is_active', 'isActive', true),
      is_critical: valueOf(item, 'is_critical', 'isCritical', false),
      position: item.position ?? index,
      choices: item.choices || [],
      choice_options: valueOf(item, 'choice_options', 'choiceOptions', []),
      category: item.category || '',
      validation_rule: rule,
      migration_metadata: item.migration_metadata || null
    };
  }),
  migration_metadata: template.migration_metadata || null
});

const canonicalTemplateInput = template => {
  const result = templateSchema.safeParse(canonicalTemplateShape(template));
  if (result.success) return result.data;
  const error = new Error(result.error.issues.map(issue => `${issue.path.join('.')}: ${issue.message}`).join('; '));
  error.statusCode = 400;
  throw error;
};

const canonicalReportInput = report => ({
  id: report.id,
  type: report.type || 'MATERIAL',
  template_id: valueOf(report, 'template_id', 'templateId', ''),
  form_code: valueOf(report, 'form_code', 'formCode', ''),
  title: report.title || '',
  status: report.status || 'DRAFT',
  staff: report.staff || { name: '', nik: '' },
  location: report.location || {},
  general_info: valueOf(report, 'general_info', 'generalInfo', {}),
  checklist_items: valueOf(report, 'checklist_items', 'checklistItems', []).map(item => ({
    id: item.id,
    parameter_name: valueOf(item, 'parameter_name', 'parameterName', item.name || ''),
    input_type: valueOf(item, 'input_type', 'inputType', 'text'),
    standard_text: valueOf(item, 'standard_text', 'standardText', ''),
    unit: item.unit || '',
    actual_value: valueOf(item, 'actual_value', 'actualValue', ''),
    staff_note: valueOf(item, 'staff_note', 'staffNote', ''),
    item_photos: valueOf(item, 'item_photos', 'itemPhotos', []),
    admin_evaluation: valueOf(item, 'admin_evaluation', 'adminEvaluation', 'PENDING'),
    admin_note: valueOf(item, 'admin_note', 'adminNote', '')
  })),
  staff_note: valueOf(report, 'staff_note', 'staffNote', ''),
  submitted_at: valueOf(report, 'submitted_at', 'submittedAt', null),
  admin_review: valueOf(report, 'admin_review', 'adminReview', null),
  general_photos: valueOf(report, 'general_photos', 'generalPhotos', []),
  revision_number: valueOf(report, 'revision_number', 'revisionNumber', 1),
  migration_metadata: report.migration_metadata || null
});

module.exports = {
  mapTemplateItemRow,
  mapTemplateAggregate,
  mapReportItemRow,
  mapReportAggregate,
  canonicalTemplateShape,
  canonicalTemplateInput,
  canonicalReportInput
};
