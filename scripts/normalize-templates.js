const fs = require('fs');
const path = require('path');
const { isDeepStrictEqual } = require('util');
const { templateSchema } = require('../src/contracts/template.contract');

const args = process.argv.slice(2);
let inputPath = '';
let outputPath = '';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--input' && args[i + 1]) {
    inputPath = path.resolve(args[i + 1]);
  } else if (args[i] === '--output' && args[i + 1]) {
    outputPath = path.resolve(args[i + 1]);
  }
}

if (!inputPath || !outputPath) {
  console.error('Error: --input and --output arguments are required');
  process.exit(1);
}

if (inputPath === outputPath) {
  console.error('Error: Input and output paths must resolve to different locations');
  process.exit(1);
}

if (!fs.existsSync(inputPath)) {
  console.error(`Error: Input file does not exist at ${inputPath}`);
  process.exit(1);
}

let rawData;
try {
  rawData = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
} catch (e) {
  console.error('Error: Input is not valid JSON:', e.message);
  process.exit(1);
}

if (!Array.isArray(rawData)) {
  console.error('Error: Input JSON must be an array of templates');
  process.exit(1);
}

const CANONICAL_TEMPLATE_KEYS = new Set([
  'id', 'type', 'name', 'description', 'form_code', 'category', 'segment', 
  'standard_code', 'is_active', 'workflow_status', 'version', 'created_at', 'updated_at',
  'checklist_items', 'migration_metadata'
]);

const CANONICAL_ITEM_KEYS = new Set([
  'id', 'parameter_name', 'input_type', 'standard_text', 'unit', 'is_required', 
  'required_photo', 'is_active', 'is_critical', 'position', 'choices', 'category',
  'validation_rule', 'migration_metadata'
]);

const KNOWN_LEGACY_TEMPLATE_KEYS = new Set(['formCode', 'standardCode', 'status', 'isActive', 'checklistItems', 'createdAt', 'updatedAt']);
const KNOWN_LEGACY_ITEM_KEYS = new Set(['parameterName', 'name', 'inputType', 'standardText', 'standardLabel', 'required', 'requiredPhoto', 'isActive', 'isCritical', 'validationRule', 'minVal', 'maxVal']);

let warningCount = 0;
let errorCount = 0;
const warnings = [];
const duplicateIdWarnings = [];
const errors = [];
const unknownFields = new Set();
const normalizedTemplates = [];
const templateIds = new Set();

const LEGACY_INPUT_TYPE_MAP = new Map([
  ['number', 'number'],
  ['text', 'text'],
  ['choice', 'choice'],
  ['boolean', 'boolean'],
  ['booleancheck', 'boolean']
]);

const LEGACY_WORKFLOW_STATUS_MAP = new Map([
  ['onprogress', 'IN_PROGRESS'],
  ['inprogress', 'IN_PROGRESS'],
  ['selesai', 'COMPLETED'],
  ['completed', 'COMPLETED']
]);

const normalizeInputType = rawValue => {
  if (typeof rawValue !== 'string') return null;
  return LEGACY_INPUT_TYPE_MAP.get(rawValue.replace(/\s+/g, '').toLowerCase()) || null;
};

rawData.forEach((tpl, tplIdx) => {
  const tplId = tpl.id || `unknown_template_${tplIdx}`;
  let hasTemplateMigrationError = false;
  const recordUnknownFields = {
    ...((tpl.migration_metadata && tpl.migration_metadata.unknown_fields) || {})
  };

  const preserveUnknownField = (fieldPath, value) => {
    recordUnknownFields[fieldPath] = value;
    unknownFields.add(`Template.${fieldPath}`);
  };
  
  if (templateIds.has(tplId)) {
    errorCount++;
    errors.push(`Duplicate template ID: "${tplId}" at index ${tplIdx}`);
  }
  templateIds.add(tplId);

  // Track unknown keys on the root template
  Object.keys(tpl).forEach(key => {
    if (!CANONICAL_TEMPLATE_KEYS.has(key) && !KNOWN_LEGACY_TEMPLATE_KEYS.has(key)) {
      preserveUnknownField(key, tpl[key]);
    }
  });

  // Normalize root fields
  let is_active = true;
  if (tpl.is_active !== undefined) {
    is_active = tpl.is_active;
  } else if (tpl.isActive !== undefined) {
    is_active = tpl.isActive;
    warningCount++;
    warnings.push(`[Template: ${tplId}] Using legacy property alias "isActive"`);
  } else {
    warningCount++;
    warnings.push(`[Template: ${tplId}] Missing "is_active", defaulting to true`);
  }

  let workflow_status = tpl.workflow_status;
  if (tpl.status !== undefined) {
    const workflowKey = typeof tpl.status === 'string'
      ? tpl.status.replace(/\s+/g, '').toLowerCase()
      : '';
    const mappedWorkflowStatus = LEGACY_WORKFLOW_STATUS_MAP.get(workflowKey);
    if (!mappedWorkflowStatus) {
      errorCount++;
      hasTemplateMigrationError = true;
      errors.push(`[Template: ${tplId}] Unsupported legacy workflow status ${JSON.stringify(tpl.status)}`);
    } else if (workflow_status === undefined) {
      workflow_status = mappedWorkflowStatus;
    } else if (workflow_status !== mappedWorkflowStatus) {
      errorCount++;
      hasTemplateMigrationError = true;
      errors.push(`[Template: ${tplId}] Canonical workflow_status "${workflow_status}" conflicts with legacy status ${JSON.stringify(tpl.status)}`);
    }
    warningCount++;
    warnings.push(`[Template: ${tplId}] Preserving legacy workflow status ${JSON.stringify(tpl.status)} as "${mappedWorkflowStatus || 'UNSUPPORTED'}"`);
  }

  let form_code = tpl.form_code || '';
  if (tpl.formCode !== undefined) {
    form_code = tpl.formCode;
    warningCount++;
    warnings.push(`[Template: ${tplId}] Using legacy property alias "formCode"`);
  }

  const created_at = tpl.created_at || tpl.createdAt || new Date().toISOString();
  if (tpl.createdAt !== undefined) {
    warningCount++;
    warnings.push(`[Template: ${tplId}] Using legacy property alias "createdAt"`);
  }

  const updated_at = tpl.updated_at || tpl.updatedAt || new Date().toISOString();
  if (tpl.updatedAt !== undefined) {
    warningCount++;
    warnings.push(`[Template: ${tplId}] Using legacy property alias "updatedAt"`);
  }

  const rawItems = tpl.checklist_items || tpl.checklistItems || [];
  if (tpl.checklistItems !== undefined) {
    warningCount++;
    warnings.push(`[Template: ${tplId}] Using legacy property alias "checklistItems"`);
  }

  const checklist_items = [];
  const itemIds = new Set();
  const originalItemsById = new Map();

  rawItems.forEach((item, itemIdx) => {
    const originalItemId = item.id || `unknown_item_${itemIdx}`;
    let itemId = originalItemId;
    let itemMigrationMetadata = item.migration_metadata;
    const previousItem = originalItemsById.get(originalItemId);

    if (previousItem) {
      previousItem.count++;
      if (isDeepStrictEqual(previousItem.item, item)) {
        errorCount++;
        hasTemplateMigrationError = true;
        errors.push(`[Template: ${tplId}] Duplicate checklist item ID "${originalItemId}" has an identical repeated item; refusing to delete or merge it`);
      } else {
        let duplicateSuffix = previousItem.count;
        itemId = `${originalItemId}__duplicate_${duplicateSuffix}`;
        while (itemIds.has(itemId)) {
          duplicateSuffix++;
          itemId = `${originalItemId}__duplicate_${duplicateSuffix}`;
        }
        itemMigrationMetadata = {
          ...(item.migration_metadata || {}),
          original_id: originalItemId,
          duplicate_id_occurrence: previousItem.count
        };
        const duplicateWarning = `[Template: ${tplId}, Item: ${originalItemId}] Migrating genuinely different duplicate checklist ID to "${itemId}"`;
        warningCount++;
        warnings.push(duplicateWarning);
        duplicateIdWarnings.push(duplicateWarning);
      }
    } else {
      originalItemsById.set(originalItemId, { item, count: 1 });
    }
    itemIds.add(itemId);

    // Track unknown keys on the checklist item
    Object.keys(item).forEach(key => {
      if (!CANONICAL_ITEM_KEYS.has(key) && !KNOWN_LEGACY_ITEM_KEYS.has(key)) {
        preserveUnknownField(`checklist_items.${itemId}.${key}`, item[key]);
      }
    });

    // Parameter name mapping
    let parameter_name = item.parameter_name || '';
    if (item.parameterName !== undefined) {
      parameter_name = item.parameterName;
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "parameterName"`);
    } else if (item.name !== undefined) {
      parameter_name = item.name;
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "name"`);
    }

    // Input type mapping
    const rawInputType = item.input_type !== undefined ? item.input_type : item.inputType;
    let input_type = rawInputType === undefined ? 'text' : normalizeInputType(rawInputType);
    if (item.inputType !== undefined) {
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "inputType"`);
    }
    if (input_type === null) {
      errorCount++;
      hasTemplateMigrationError = true;
      errors.push(`[Template: ${tplId}, Item: ${itemId}] Unsupported input type ${JSON.stringify(rawInputType)}; supported canonical values are number, text, choice, and boolean`);
      input_type = rawInputType;
    } else if (rawInputType !== undefined && rawInputType !== input_type) {
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Normalizing input type ${JSON.stringify(rawInputType)} to "${input_type}"`);
    }

    // Standard text mapping
    let standard_text = item.standard_text || '';
    if (item.standardText !== undefined) {
      standard_text = item.standardText;
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "standardText"`);
    } else if (item.standardLabel !== undefined) {
      standard_text = item.standardLabel;
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "standardLabel"`);
    }

    // Is required / required photo mapping
    let is_required = true;
    if (item.is_required !== undefined) {
      is_required = item.is_required;
    } else if (item.required !== undefined) {
      is_required = item.required;
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "required"`);
    }

    let required_photo = false;
    if (item.required_photo !== undefined) {
      required_photo = item.required_photo;
    } else if (item.requiredPhoto !== undefined) {
      required_photo = item.requiredPhoto;
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "requiredPhoto"`);
    }

    let is_active_item = true;
    if (item.is_active !== undefined) {
      is_active_item = item.is_active;
    } else if (item.isActive !== undefined) {
      is_active_item = item.isActive;
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "isActive"`);
    } else {
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Missing "is_active" for item, defaulting to true`);
    }

    let is_critical = false;
    if (item.is_critical !== undefined) {
      is_critical = item.is_critical;
    } else if (item.isCritical !== undefined) {
      is_critical = item.isCritical;
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "isCritical"`);
    }

    const position = item.position !== undefined ? item.position : itemIdx;

    // Validation rule mapping
    let validation_rule = null;
    const legacyRule = item.validationRule || item.validation_rule || {};
    if (item.validationRule !== undefined) {
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "validationRule"`);
    }

    const min_value = typeof item.minVal === 'number' ? item.minVal : 
                      (typeof legacyRule.minVal === 'number' ? legacyRule.minVal : 
                      (typeof legacyRule.min_value === 'number' ? legacyRule.min_value : null));
    if (item.minVal !== undefined || legacyRule.minVal !== undefined) {
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "minVal"`);
    }

    const max_value = typeof item.maxVal === 'number' ? item.maxVal : 
                      (typeof legacyRule.maxVal === 'number' ? legacyRule.maxVal : 
                      (typeof legacyRule.max_value === 'number' ? legacyRule.max_value : null));
    if (item.maxVal !== undefined || legacyRule.maxVal !== undefined) {
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "maxVal"`);
    }

    const exact_value = legacyRule.exactValue !== undefined ? legacyRule.exactValue : 
                        (legacyRule.exact_value !== undefined ? legacyRule.exact_value : null);
    if (legacyRule.exactValue !== undefined) {
      warningCount++;
      warnings.push(`[Template: ${tplId}, Item: ${itemId}] Using legacy property alias "exactValue"`);
    }

    const type = legacyRule.type || null;

    if (type || min_value !== null || max_value !== null || exact_value !== null) {
      validation_rule = {
        type,
        min_value,
        max_value,
        exact_value
      };
    }

    checklist_items.push({
      id: itemId,
      parameter_name,
      input_type,
      standard_text,
      unit: item.unit || '',
      is_required,
      required_photo,
      is_active: is_active_item,
      is_critical,
      position,
      choices: item.choices || [],
      category: item.category || '',
      validation_rule,
      migration_metadata: itemMigrationMetadata
    });
  });

  // Sort checklist items by position
  checklist_items.sort((a, b) => a.position - b.position);

  const migration_metadata = {
    ...(tpl.migration_metadata || {}),
    ...(tpl.status !== undefined ? { legacy_workflow_status: tpl.status } : {}),
    ...(Object.keys(recordUnknownFields).length > 0 ? { unknown_fields: recordUnknownFields } : {})
  };

  const normalized = {
    id: tplId,
    type: tpl.type || 'MATERIAL',
    name: tpl.name || '',
    description: tpl.description || '',
    form_code,
    category: tpl.category || '',
    segment: tpl.segment || 'construction',
    standard_code: tpl.standard_code || tpl.standardCode || '',
    is_active,
    workflow_status,
    version: tpl.version || 1,
    created_at,
    updated_at,
    checklist_items,
    migration_metadata: Object.keys(migration_metadata).length > 0 ? migration_metadata : undefined
  };

  if (tpl.standardCode !== undefined) {
    warningCount++;
    warnings.push(`[Template: ${tplId}] Using legacy property alias "standardCode"`);
  }

  // Zod validation
  if (!hasTemplateMigrationError) {
    try {
      templateSchema.parse(normalized);
    } catch (zodErr) {
      errorCount++;
      errors.push(`[Template: ${tplId}] Zod validation failed: ${JSON.stringify(zodErr.format())}`);
    }
  }

  normalizedTemplates.push(normalized);
});

// Output Summary
console.log('--- Template Normalization Summary ---');
console.log(`Total records read: ${rawData.length}`);
console.log(`Normalized records: ${normalizedTemplates.length}`);
console.log(`Warnings generated: ${warningCount}`);
console.log(`Errors encountered: ${errorCount}`);

if (unknownFields.size > 0) {
  console.log('Unknown fields detected (preserved in migration_metadata.unknown_fields):');
  unknownFields.forEach(f => console.log(` - ${f}`));
}

if (warnings.length > 0) {
  console.log('\nWarnings Details (first 10):');
  warnings.slice(0, 10).forEach(w => console.log(`  [WARN] ${w}`));
  if (warnings.length > 10) console.log(`  ... and ${warnings.length - 10} more warnings.`);
}

if (duplicateIdWarnings.length > 0) {
  console.log('\nDuplicate ID Migration Warnings:');
  duplicateIdWarnings.forEach(w => console.log(`  [WARN] ${w}`));
}

if (errors.length > 0) {
  console.error('\nErrors Details:');
  errors.forEach(e => console.error(`  [ERROR] ${e}`));
  process.exit(1);
}

// Atomic output write
const tempPath = `${outputPath}.${Date.now()}.tmp`;
try {
  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(tempPath, JSON.stringify(normalizedTemplates, null, 2), 'utf8');
  fs.renameSync(tempPath, outputPath);
  console.log(`\nSuccessfully wrote normalized templates to ${outputPath}`);
  process.exit(0);
} catch (e) {
  try {
    if (fs.existsSync(tempPath)) {
      fs.unlinkSync(tempPath);
    }
  } catch (_) {}
  console.error(`\nFailed to write normalized output file: ${e.message}`);
  process.exit(1);
}
