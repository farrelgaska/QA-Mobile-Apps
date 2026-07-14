const { z } = require('zod');
const { isoDateSchema } = require('./common.contract');

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

const adminReviewSchema = z.object({
  admin_note: z.string().nullable().optional().default(""),
  conclusion: z.enum(["PASSED", "NOT_PASSED", "FAILED", "NEEDS_FOLLOW_UP"]).nullable().optional().default(null),
  reviewed_at: isoDateSchema.nullable().optional(),
  reviewed_by: z.string().nullable().optional().default(null)
}).nullable().optional();

const conclusionMigrationSchema = z.object({
  original_value: z.string().nullable(),
  canonical_value: z.enum(["PASSED", "NOT_PASSED", "FAILED", "NEEDS_FOLLOW_UP"]).nullable(),
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
  revision_number: z.number().int().default(1),
  migration_metadata: migrationMetadataSchema
}).superRefine((report, ctx) => {
  const conclusion = report.admin_review?.conclusion ?? null;
  const requiresFinalConclusion = ['SUBMITTED', 'NEEDS_FOLLOW_UP', 'APPROVED'].includes(report.status);

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
  adminReviewSchema,
  conclusionMigrationSchema,
  migrationMetadataSchema,
  reportSchema
};
