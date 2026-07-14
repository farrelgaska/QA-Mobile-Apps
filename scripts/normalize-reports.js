const fs = require('fs');
const path = require('path');
const { reportSchema } = require('../src/contracts/report.contract');

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
  console.error('Error: Input JSON must be an array of reports');
  process.exit(1);
}

const CANONICAL_REPORT_KEYS = new Set([
  'id', 'type', 'template_id', 'form_code', 'title', 'status', 'staff', 'location', 
  'general_info', 'checklist_items', 'staff_note', 'submitted_at', 'admin_review', 
  'general_photos', 'revision_number', 'migration_metadata'
]);

const CANONICAL_STAFF_KEYS = new Set(['name', 'nik']);
const CANONICAL_LOCATION_KEYS = new Set(['site_id', 'site_name', 'area', 'detail_location']);
const CANONICAL_REVIEW_KEYS = new Set(['admin_note', 'conclusion', 'reviewed_at']);
const CANONICAL_ITEM_KEYS = new Set([
  'id', 'parameter_name', 'input_type', 'standard_text', 'unit', 'actual_value', 
  'staff_note', 'item_photos', 'admin_evaluation', 'admin_note'
]);

const KNOWN_LEGACY_REPORT_KEYS = new Set(['revision_history', 'templateId', 'formCode', 'submittedAt']);
const KNOWN_LEGACY_ITEM_KEYS = new Set(['parameterName', 'inputType', 'standardText', 'standardLabel', 'actualValue', 'staffNote', 'itemPhotos', 'adminEvaluation', 'adminNote']);

let warningCount = 0;
let errorCount = 0;
const warnings = [];
const errors = [];
const unknownFields = new Set();
const normalizedReports = [];
const reportIds = new Set();

rawData.forEach((rep, repIdx) => {
  const repId = rep.id || `unknown_report_${repIdx}`;
  
  if (reportIds.has(repId)) {
    errorCount++;
    errors.push(`Duplicate report ID: "${repId}" at index ${repIdx}`);
  }
  reportIds.add(repId);

  // Track unknown keys on root
  Object.keys(rep).forEach(key => {
    if (!CANONICAL_REPORT_KEYS.has(key) && !KNOWN_LEGACY_REPORT_KEYS.has(key)) {
      unknownFields.add(`Report.${key}`);
    }
  });

  // Staff normalization
  const rawStaff = rep.staff || {};
  Object.keys(rawStaff).forEach(key => {
    if (!CANONICAL_STAFF_KEYS.has(key)) {
      unknownFields.add(`Report.staff.${key}`);
    }
  });
  const staff = {
    name: rawStaff.name || '',
    nik: rawStaff.nik || ''
  };

  // Location normalization
  const rawLocation = rep.location || {};
  Object.keys(rawLocation).forEach(key => {
    if (!CANONICAL_LOCATION_KEYS.has(key)) {
      unknownFields.add(`Report.location.${key}`);
    }
  });
  const location = {
    site_id: rawLocation.site_id || rawLocation.siteId || '',
    site_name: rawLocation.site_name || rawLocation.siteName || '',
    area: rawLocation.area || '',
    detail_location: rawLocation.detail_location || rawLocation.detailLocation || ''
  };
  if (rawLocation.siteId || rawLocation.siteName || rawLocation.detailLocation) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property aliases in location object`);
  }

  // Admin Review / Conclusion normalization
  let admin_review = null;
  if (rep.admin_review || rep.adminReview) {
    const rawReview = rep.admin_review || rep.adminReview;
    if (rep.adminReview) {
      warningCount++;
      warnings.push(`[Report: ${repId}] Using legacy property alias "adminReview"`);
    }

    Object.keys(rawReview).forEach(key => {
      if (!CANONICAL_REVIEW_KEYS.has(key)) {
        unknownFields.add(`Report.admin_review.${key}`);
      }
    });

    let conclusion = null;
    const rawConclusion = rawReview.conclusion;
    if (rawConclusion === 'Lulus' || rawConclusion === 'PASSED') {
      conclusion = 'PASSED';
      if (rawConclusion === 'Lulus') {
        warningCount++;
        warnings.push(`[Report: ${repId}] Normalizing legacy conclusion "Lulus" to "PASSED"`);
      }
    } else if (rawConclusion === 'Tidak Lulus' || rawConclusion === 'NOT_PASSED') {
      conclusion = 'NOT_PASSED';
      if (rawConclusion === 'Tidak Lulus') {
        warningCount++;
        warnings.push(`[Report: ${repId}] Normalizing legacy conclusion "Tidak Lulus" to "NOT_PASSED"`);
      }
    } else if (rawConclusion !== undefined && rawConclusion !== null) {
      warningCount++;
      warnings.push(`[Report: ${repId}] Unknown conclusion value "${rawConclusion}", mapping to null`);
    }

    admin_review = {
      admin_note: rawReview.admin_note || rawReview.adminNote || '',
      conclusion,
      reviewed_at: rawReview.reviewed_at || rawReview.reviewedAt || null
    };

    if (rawReview.adminNote || rawReview.reviewedAt) {
      warningCount++;
      warnings.push(`[Report: ${repId}] Using legacy property aliases in admin_review`);
    }
  }

  // Checklist items
  const rawItems = rep.checklist_items || rep.checklistItems || [];
  if (rep.checklistItems !== undefined) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property alias "checklistItems"`);
  }

  const checklist_items = [];
  const itemIds = new Set();

  rawItems.forEach((item, itemIdx) => {
    const itemId = item.id || `unknown_item_${itemIdx}`;
    
    if (itemIds.has(itemId)) {
      errorCount++;
      errors.push(`[Report: ${repId}] Duplicate checklist item ID: "${itemId}"`);
    }
    itemIds.add(itemId);

    Object.keys(item).forEach(key => {
      if (!CANONICAL_ITEM_KEYS.has(key) && !KNOWN_LEGACY_ITEM_KEYS.has(key)) {
        unknownFields.add(`Report.Item.${key}`);
      }
    });

    // Parameter name mapping
    let parameter_name = item.parameter_name || '';
    if (item.parameterName !== undefined) {
      parameter_name = item.parameterName;
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "parameterName"`);
    }

    // Input type mapping
    let input_type = item.input_type || item.inputType || 'text';
    if (item.inputType !== undefined) {
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "inputType"`);
    }
    if (input_type === 'booleanCheck') {
      input_type = 'boolean';
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Normalizing "booleanCheck" input_type to "boolean"`);
    }

    // Standard text mapping
    let standard_text = item.standard_text || '';
    if (item.standardText !== undefined) {
      standard_text = item.standardText;
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "standardText"`);
    } else if (item.standardLabel !== undefined) {
      standard_text = item.standardLabel;
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "standardLabel"`);
    }

    // Actual value mapping
    let actual_value = '';
    if (item.actual_value !== undefined) {
      actual_value = String(item.actual_value);
    } else if (item.actualValue !== undefined) {
      actual_value = String(item.actualValue);
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "actualValue"`);
    }

    // Evaluation mapping
    let admin_evaluation = item.admin_evaluation || item.adminEvaluation || 'PENDING';
    if (item.adminEvaluation !== undefined) {
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "adminEvaluation"`);
    }

    // Staff note
    let staff_note = item.staff_note || '';
    if (item.staffNote !== undefined) {
      staff_note = item.staffNote;
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "staffNote"`);
    }

    // Item photos
    let item_photos = item.item_photos || item.itemPhotos || [];
    if (item.itemPhotos !== undefined) {
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "itemPhotos"`);
    }

    // Admin note
    let admin_note = item.admin_note || item.adminNote || '';
    if (item.adminNote !== undefined) {
      admin_note = item.adminNote;
      warningCount++;
      warnings.push(`[Report: ${repId}, Item: ${itemId}] Using legacy property alias "adminNote"`);
    }

    checklist_items.push({
      id: itemId,
      parameter_name,
      input_type,
      standard_text,
      unit: item.unit || '',
      actual_value,
      staff_note,
      item_photos,
      admin_evaluation,
      admin_note
    });
  });

  // Preserve legacy revision_history as migration metadata
  const revision_history = rep.revision_history || [];
  const migration_metadata = {
    legacy_revision_history: revision_history
  };

  const normalized = {
    id: repId,
    type: rep.type || 'MATERIAL',
    template_id: rep.template_id || rep.templateId || '',
    form_code: rep.form_code || rep.formCode || '',
    title: rep.title || '',
    status: rep.status || 'DRAFT',
    staff,
    location,
    general_info: rep.general_info || {},
    checklist_items,
    staff_note: rep.staff_note || '',
    submitted_at: rep.submitted_at || rep.submittedAt || null,
    admin_review,
    general_photos: rep.general_photos || [],
    revision_number: rep.revision_number !== undefined ? rep.revision_number : 1,
    migration_metadata
  };

  if (rep.templateId !== undefined) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property alias "templateId"`);
  }
  if (rep.formCode !== undefined) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property alias "formCode"`);
  }
  if (rep.submittedAt !== undefined) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property alias "submittedAt"`);
  }

  // Zod validation
  try {
    reportSchema.parse(normalized);
  } catch (zodErr) {
    errorCount++;
    errors.push(`[Report: ${repId}] Zod validation failed: ${JSON.stringify(zodErr.format())}`);
  }

  normalizedReports.push(normalized);
});

// Output Summary
console.log('--- Report Normalization Summary ---');
console.log(`Total records read: ${rawData.length}`);
console.log(`Normalized records: ${normalizedReports.length}`);
console.log(`Warnings generated: ${warningCount}`);
console.log(`Errors encountered: ${errorCount}`);

if (unknownFields.size > 0) {
  console.log('Unknown fields detected (will be skipped):');
  unknownFields.forEach(f => console.log(` - ${f}`));
}

if (warnings.length > 0) {
  console.log('\nWarnings Details (first 10):');
  warnings.slice(0, 10).forEach(w => console.log(`  [WARN] ${w}`));
  if (warnings.length > 10) console.log(`  ... and ${warnings.length - 10} more warnings.`);
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
  fs.writeFileSync(tempPath, JSON.stringify(normalizedReports, null, 2), 'utf8');
  fs.renameSync(tempPath, outputPath);
  console.log(`\nSuccessfully wrote normalized reports to ${outputPath}`);
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
