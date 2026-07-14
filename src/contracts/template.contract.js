const { z } = require('zod');
const { isoDateSchema } = require('./common.contract');

const validationRuleSchema = z.object({
  type: z.string().nullable().optional(),
  min_value: z.number().nullable().optional(),
  max_value: z.number().nullable().optional(),
  exact_value: z.any().nullable().optional()
}).nullable().optional();

const checklistItemSchema = z.object({
  id: z.string(),
  parameter_name: z.string(),
  input_type: z.enum(["number", "text", "choice", "boolean"]),
  standard_text: z.string().nullable().optional().default(""),
  unit: z.string().nullable().optional().default(""),
  is_required: z.boolean(),
  required_photo: z.boolean(),
  is_active: z.boolean().default(true),
  is_critical: z.boolean().default(false),
  position: z.number().int().default(0),
  choices: z.array(z.string()).nullable().optional().default([]),
  validation_rule: validationRuleSchema
});

const migrationMetadataSchema = z.object({
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
  version: z.number().int().default(1),
  created_at: isoDateSchema,
  updated_at: isoDateSchema,
  checklist_items: z.array(checklistItemSchema),
  migration_metadata: migrationMetadataSchema
});

module.exports = {
  validationRuleSchema,
  checklistItemSchema,
  migrationMetadataSchema,
  templateSchema
};
