const { z } = require('zod');
const { isoDateSchema } = require('./common.contract');

const validationRuleSchema = z.object({
  type: z.string().nullable().optional(),
  min_value: z.number().nullable().optional(),
  max_value: z.number().nullable().optional(),
  exact_value: z.any().nullable().optional()
}).nullable().optional();

const choiceOptionSchema = z.object({
  id: z.string().trim().min(1),
  label: z.string().trim().min(1),
  value: z.string(),
  outcome: z.enum(['PASS', 'FAIL']),
  position: z.number().int().min(0)
});

const checklistItemMigrationMetadataSchema = z.object({
  original_id: z.string().optional(),
  duplicate_id_occurrence: z.number().int().min(2).optional()
}).nullable().optional();

const checklistItemSchema = z.object({
  id: z.string(),
  parameter_name: z.string(),
  input_type: z.enum(['number', 'text', 'choice', 'boolean']),
  standard_text: z.string().default(''),
  min_value: z.number().nullable().default(null),
  max_value: z.number().nullable().default(null),
  unit: z.string().nullable().default(null),
  is_required: z.boolean(),
  required_photo: z.boolean(),
  is_active: z.boolean().default(true),
  is_critical: z.boolean().default(false),
  position: z.number().int().default(0),
  choices: z.array(z.string()).nullable().optional().default([]),
  choice_options: z.array(choiceOptionSchema).default([]),
  category: z.string().nullable().optional().default(""),
  validation_rule: validationRuleSchema,
  migration_metadata: checklistItemMigrationMetadataSchema
}).superRefine((item, context) => {
  if (item.input_type === 'number') {
    if (item.min_value !== null && item.max_value !== null && item.min_value > item.max_value) {
      context.addIssue({ code: 'custom', path: ['min_value'], message: 'min_value must be less than or equal to max_value' });
    }
    if (item.choices.length > 0 || item.choice_options.length > 0) {
      context.addIssue({ code: 'custom', path: ['choice_options'], message: 'number items cannot define choices' });
    }
  }

  if (item.input_type === 'text') {
    if (item.min_value !== null || item.max_value !== null) {
      context.addIssue({ code: 'custom', path: ['min_value'], message: 'text items cannot define numeric bounds' });
    }
    if (item.choices.length > 0 || item.choice_options.length > 0) {
      context.addIssue({ code: 'custom', path: ['choice_options'], message: 'text items cannot define choices' });
    }
  }

  if (item.input_type === 'boolean') {
    if (item.min_value !== null || item.max_value !== null) {
      context.addIssue({ code: 'custom', path: ['min_value'], message: 'boolean items cannot define numeric bounds' });
    }
    if (item.choices.length > 0 || item.choice_options.length > 0) {
      context.addIssue({ code: 'custom', path: ['choice_options'], message: 'boolean items cannot define choices' });
    }
  }

  if (item.input_type === 'choice') {
    if (item.min_value !== null || item.max_value !== null) {
      context.addIssue({ code: 'custom', path: ['min_value'], message: 'choice items cannot define numeric bounds' });
    }
    if (!item.choice_options.some(option => option.outcome === 'PASS')) {
      context.addIssue({ code: 'custom', path: ['choice_options'], message: 'choice items require at least one PASS option' });
    }
    if (!item.choice_options.some(option => option.outcome === 'FAIL')) {
      context.addIssue({ code: 'custom', path: ['choice_options'], message: 'choice items require at least one FAIL option' });
    }
  }
});

const migrationMetadataSchema = z.object({
  legacy_workflow_status: z.string().optional(),
  unknown_fields: z.record(z.any()).optional()
}).nullable().optional();

const templateSchema = z.object({
  id: z.string(),
  type: z.enum(["MATERIAL", "WORK"]),
  name: z.string(),
  description: z.string().nullable().optional().default(""),
  form_code: z.string().nullable().optional().default(""),
  category: z.string().nullable().optional().default(""),
  segment: z.string().nullable().optional().default("construction"),
  standard_code: z.string().nullable().optional().default(""),
  is_active: z.boolean().default(true),
  workflow_status: z.enum(["IN_PROGRESS", "COMPLETED"]).nullable().optional(),
  version: z.number().int().default(1),
  created_at: isoDateSchema,
  updated_at: isoDateSchema,
  checklist_items: z.array(checklistItemSchema),
  migration_metadata: migrationMetadataSchema
});

module.exports = {
  validationRuleSchema,
  choiceOptionSchema,
  checklistItemMigrationMetadataSchema,
  checklistItemSchema,
  migrationMetadataSchema,
  templateSchema
};
