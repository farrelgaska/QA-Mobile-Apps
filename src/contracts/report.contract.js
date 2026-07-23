const { z } = require('zod');
const { isoDateSchema } = require('./common.contract');

const CANONICAL_QC_EVIDENCE_PATH_PATTERN =
  /^reports\/[A-Za-z0-9_-]{1,128}\/(?:general\/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|checklist\/[A-Za-z0-9_-]{1,128}\/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.(?:jpg|png|webp|heic)$/;
const SAMPLE_INSPECTION_STATUSES = ['NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'];
const PARAMETER_EVALUATION_STATUSES = [
  'NOT_EVALUATED',
  'WITHIN_STANDARD',
  'OUT_OF_STANDARD'
];

const staffSchema = z.object({
  name: z.string().default(""),
  nik: z.string().default("")
});

const locationSchema = z.object({
  site_id: z.string().nullable().optional().default(""),
  site_name: z.string().nullable().optional().default(""),
  area: z.string().nullable().optional().default(""),
  detail_location: z.string().nullable().optional().default("")
});

const reportChecklistItemSchema = z.object({
  id: z.string(),
  parameter_name: z.string(),
  input_type: z.enum(["number", "text", "choice", "boolean"]),
  standard_text: z.string().nullable().optional().default(""),
  unit: z.string().nullable().optional().default(""),
  actual_value: z.string().nullable().optional().default(""),
  staff_note: z.string().nullable().optional().default(""),
  item_photos: z.array(z.string()).default([]),
  admin_evaluation: z.enum(["PASS", "FAIL", "NEEDS_REVIEW", "PENDING"]).default("PENDING"),
  admin_note: z.string().nullable().optional().default("")
});

const canonicalPhotoPathSchema = z.string().regex(
  CANONICAL_QC_EVIDENCE_PATH_PATTERN,
  'photo path must be a canonical QC evidence object_path'
);

const sampleChecklistAnswerSchema = z.object({
  checklist_item_id: z.string().min(1),
  input_type: z.enum(['number', 'text', 'choice', 'boolean']),
  actual_value: z.union([z.string(), z.number().finite(), z.boolean(), z.null()]).default(''),
  note: z.string().nullable().optional().default(''),
  photo_paths: z.array(canonicalPhotoPathSchema).default([]),
  standard_text: z.string().default(''),
  standard_value: z.number().finite().nullable().optional().default(null),
  unit: z.string().nullable().optional().default(''),
  upper_tolerance: z.number().finite().nullable().optional().default(null),
  lower_tolerance: z.number().finite().nullable().optional().default(null),
  minimum_value: z.number().finite().nullable().optional().default(null),
  maximum_value: z.number().finite().nullable().optional().default(null),
  evaluation_status: z.enum(PARAMETER_EVALUATION_STATUSES).default('NOT_EVALUATED')
}).superRefine((answer, ctx) => {
  if (answer.minimum_value !== null &&
      answer.maximum_value !== null &&
      answer.minimum_value > answer.maximum_value) {
    ctx.addIssue({
      code: 'custom',
      path: ['maximum_value'],
      message: 'maximum_value must be greater than or equal to minimum_value'
    });
  }
});

const reportSampleSchema = z.object({
  id: z.string().min(1).max(128).regex(
    /^[A-Za-z0-9_-]+$/,
    'sample id may contain only letters, numbers, underscores, or hyphens'
  ),
  sample_number: z.number().int().positive(),
  inspection_status: z.enum(SAMPLE_INSPECTION_STATUSES).default('NOT_STARTED'),
  checklist_answers: z.array(sampleChecklistAnswerSchema).default([]),
  notes: z.string().nullable().optional().default(''),
  photo_paths: z.array(canonicalPhotoPathSchema).default([]),
  created_at: isoDateSchema,
  updated_at: isoDateSchema
}).superRefine((sample, ctx) => {
  const itemIds = new Set();
  for (let index = 0; index < sample.checklist_answers.length; index++) {
    const itemId = sample.checklist_answers[index].checklist_item_id;
    if (itemIds.has(itemId)) {
      ctx.addIssue({
        code: 'custom',
        path: ['checklist_answers', index, 'checklist_item_id'],
        message: `duplicate checklist_item_id: ${itemId}`
      });
    }
    itemIds.add(itemId);
  }
});

const reportSamplesSchema = z.array(reportSampleSchema).superRefine((samples, ctx) => {
  const ids = new Set();
  const numbers = new Set();
  for (let index = 0; index < samples.length; index++) {
    const sample = samples[index];
    if (ids.has(sample.id)) {
      ctx.addIssue({
        code: 'custom',
        path: [index, 'id'],
        message: `duplicate sample id: ${sample.id}`
      });
    }
    if (numbers.has(sample.sample_number)) {
      ctx.addIssue({
        code: 'custom',
        path: [index, 'sample_number'],
        message: `duplicate sample_number: ${sample.sample_number}`
      });
    }
    ids.add(sample.id);
    numbers.add(sample.sample_number);
  }
});

const sampleFieldsSchema = z.object({
  sample_count: z.number().int().positive(),
  samples: reportSamplesSchema
});

const sampleValidationError = issues => {
  const error = new Error(issues
    .map(issue => `${issue.path.join('.') || 'samples'}: ${issue.message}`)
    .join('; '));
  error.statusCode = 400;
  return error;
};

const normalizeReportSampleFields = report => {
  const rawSamples = report.samples ?? [];
  const sampleCount = report.sample_count ?? report.sampleCount ??
    (rawSamples.length > 0 ? rawSamples.length : 1);
  const now = new Date().toISOString();
  const candidate = {
    sample_count: sampleCount,
    samples: rawSamples.map(sample => ({
      ...sample,
      created_at: sample.created_at ?? sample.createdAt ?? now,
      updated_at: sample.updated_at ?? sample.updatedAt ?? sample.created_at ?? sample.createdAt ?? now
    }))
  };
  const result = sampleFieldsSchema.safeParse(candidate);
  if (!result.success) throw sampleValidationError(result.error.issues);
  return result.data;
};

const mergeReportSamplePatch = (currentSamples, patchedSamples) => {
  if (patchedSamples.length === 0) return [];
  const patchedById = new Map(patchedSamples.map(sample => [sample.id, sample]));
  const currentIds = new Set(currentSamples.map(sample => sample.id));
  return [
    ...currentSamples.map(sample => patchedById.get(sample.id) || sample),
    ...patchedSamples.filter(sample => !currentIds.has(sample.id))
  ];
};

const adminReviewSchema = z.object({
  admin_note: z.string().nullable().optional().default(""),
  conclusion: z.enum(["PASSED", "NOT_PASSED"]).nullable().optional().default(null),
  reviewed_at: isoDateSchema.nullable().optional(),
  reviewed_by: z.string().nullable().optional().default(null)
}).nullable().optional();

const conclusionMigrationSchema = z.object({
  original_value: z.string().nullable(),
  canonical_value: z.enum(["PASSED", "NOT_PASSED"]).nullable(),
  reason: z.literal("UNFINISHED_REPORT"),
  source_status: z.enum(["DRAFT", "SUBMITTED", "NEEDS_FOLLOW_UP", "APPROVED"])
}).optional();

const migrationMetadataSchema = z.object({
  legacy_revision_history: z.array(z.any()).optional(),
  conclusion_migration: conclusionMigrationSchema,
  unknown_fields: z.record(z.any()).optional()
}).nullable().optional();

const reportSchema = z.object({
  id: z.string(),
  type: z.enum(["MATERIAL", "WORK"]),
  template_id: z.string().nullable().optional().default(""),
  form_code: z.string().nullable().optional().default(""),
  title: z.string(),
  status: z.enum(["DRAFT", "SUBMITTED", "NEEDS_FOLLOW_UP", "APPROVED"]),
  staff: staffSchema,
  location: locationSchema,
  general_info: z.record(z.any()).nullable().optional().default({}),
  checklist_items: z.array(reportChecklistItemSchema),
  staff_note: z.string().nullable().optional().default(""),
  submitted_at: isoDateSchema.nullable().optional(),
  admin_review: adminReviewSchema,
  general_photos: z.array(z.string()).default([]),
  sample_count: z.number().int().positive().default(1),
  samples: reportSamplesSchema.default([]),
  revision_number: z.number().int().default(1),
  migration_metadata: migrationMetadataSchema
}).superRefine((report, ctx) => {
  const conclusion = report.admin_review?.conclusion ?? null;
  const requiresFinalConclusion = ['NEEDS_FOLLOW_UP', 'APPROVED'].includes(report.status);

  if (requiresFinalConclusion && conclusion === null) {
    ctx.addIssue({
      code: 'custom',
      path: ['admin_review', 'conclusion'],
      message: `Report status ${report.status} requires an explicit final conclusion; manual resolution is required`
    });
  }
});

module.exports = {
  staffSchema,
  locationSchema,
  reportChecklistItemSchema,
  CANONICAL_QC_EVIDENCE_PATH_PATTERN,
  SAMPLE_INSPECTION_STATUSES,
  PARAMETER_EVALUATION_STATUSES,
  sampleChecklistAnswerSchema,
  reportSampleSchema,
  reportSamplesSchema,
  normalizeReportSampleFields,
  mergeReportSamplePatch,
  adminReviewSchema,
  conclusionMigrationSchema,
  migrationMetadataSchema,
  reportSchema
};
