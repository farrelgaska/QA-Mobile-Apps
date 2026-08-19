const fs = require('fs');
const path = require('path');
const { reportSchema } = require('../src/contracts/report.contract');

const args = process.argv.slice(2);
let inputPath = '';
let outputPath = '';
let quarantineManifestPath = '';
let quarantineOutputPath = '';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--input' && args[i + 1]) {
    inputPath = path.resolve(args[i + 1]);
  } else if (args[i] === '--output' && args[i + 1]) {
    outputPath = path.resolve(args[i + 1]);
  } else if (args[i] === '--quarantine-manifest' && args[i + 1]) {
    quarantineManifestPath = path.resolve(args[i + 1]);
  } else if (args[i] === '--quarantine-output' && args[i + 1]) {
    quarantineOutputPath = path.resolve(args[i + 1]);
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

if (quarantineOutputPath && !quarantineManifestPath) {
  console.error('Error: --quarantine-output requires --quarantine-manifest');
  process.exit(1);
}

if (quarantineManifestPath && !quarantineOutputPath) {
  const extension = path.extname(outputPath) || '.json';
  const outputStem = path.extname(outputPath)
    ? outputPath.slice(0, -path.extname(outputPath).length)
    : outputPath;
  quarantineOutputPath = `${outputStem}.quarantine${extension}`;
}

const resolvedPaths = [inputPath, outputPath, quarantineManifestPath, quarantineOutputPath].filter(Boolean);
if (new Set(resolvedPaths).size !== resolvedPaths.length) {
  console.error('Error: Input, output, quarantine manifest, and quarantine output paths must be distinct');
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

const quarantineById = new Map();
if (quarantineManifestPath) {
  if (!fs.existsSync(quarantineManifestPath)) {
    console.error(`Error: Quarantine manifest does not exist at ${quarantineManifestPath}`);
    process.exit(1);
  }

  let manifestData;
  try {
    manifestData = JSON.parse(fs.readFileSync(quarantineManifestPath, 'utf8'));
  } catch (e) {
    console.error('Error: Quarantine manifest is not valid JSON:', e.message);
    process.exit(1);
  }

  if (!Array.isArray(manifestData)) {
    console.error('Error: Quarantine manifest must be a JSON array');
    process.exit(1);
  }

  manifestData.forEach((entry, index) => {
    if (!entry || typeof entry.id !== 'string' || entry.id.trim() === '') {
      console.error(`Error: Quarantine manifest entry at index ${index} must have a non-empty id`);
      process.exit(1);
    }
    if (quarantineById.has(entry.id)) {
      console.error(`Error: Quarantine manifest contains duplicate ID "${entry.id}"`);
      process.exit(1);
    }
    if (typeof entry.reason !== 'string' || entry.reason.trim() === '') {
      console.error(`Error: Quarantine manifest entry "${entry.id}" must have a non-empty reason`);
      process.exit(1);
    }
    if (typeof entry.disposition !== 'string' || entry.disposition.trim() === '') {
      console.error(`Error: Quarantine manifest entry "${entry.id}" must have a non-empty disposition`);
      process.exit(1);
    }
    quarantineById.set(entry.id, entry);
  });

  const sourceIds = new Set(rawData.map(report => report && report.id).filter(Boolean));
  quarantineById.forEach((_, id) => {
    if (!sourceIds.has(id)) {
      console.error(`Error: Quarantined ID "${id}" does not exist in the source`);
      process.exit(1);
    }
  });
}

const CANONICAL_REPORT_KEYS = new Set([
  'id', 'type', 'template_id', 'form_code', 'title', 'status', 'staff', 'location', 
  'general_info', 'checklist_items', 'staff_note', 'submitted_at', 'admin_review', 
  'general_photos', 'revision_number', 'migration_metadata'
]);

const CANONICAL_STAFF_KEYS = new Set(['name', 'nik']);
const CANONICAL_LOCATION_KEYS = new Set(['site_id', 'site_name', 'area', 'detail_location']);
const CANONICAL_REVIEW_KEYS = new Set(['admin_note', 'conclusion', 'reviewed_at', 'reviewed_by']);
const CANONICAL_ITEM_KEYS = new Set([
  'id', 'parameter_name', 'input_type', 'standard_text', 'unit', 'actual_value', 
  'staff_note', 'item_photos', 'admin_evaluation', 'admin_note'
]);

const KNOWN_LEGACY_REPORT_KEYS = new Set([
  'revision_history', 'revisionHistory', 'templateId', 'formCode', 'checklistItems',
  'staffNote', 'submittedAt', 'adminReview', 'generalPhotos', 'revisionNumber'
]);
const KNOWN_LEGACY_LOCATION_KEYS = new Set(['siteId', 'siteName', 'detailLocation']);
const KNOWN_LEGACY_REVIEW_KEYS = new Set(['adminNote', 'reviewedAt', 'reviewedBy']);
const KNOWN_LEGACY_ITEM_KEYS = new Set(['parameterName', 'inputType', 'standardText', 'standardLabel', 'actualValue', 'staffNote', 'itemPhotos', 'adminEvaluation', 'adminNote']);

let warningCount = 0;
let errorCount = 0;
const warnings = [];
const errors = [];
const unknownFields = new Set();
const normalizedReports = [];
const quarantinedReports = [];
const reportIds = new Set();

rawData.forEach((rep, repIdx) => {
  const repId = rep.id || `unknown_report_${repIdx}`;
  const quarantineEntry = quarantineById.get(repId);
  if (quarantineEntry) {
    quarantinedReports.push({
      record: rep,
      reason: quarantineEntry.reason,
      disposition: quarantineEntry.disposition
    });
    return;
  }
  const reportStatus = rep.status || 'DRAFT';
  const existingMigrationMetadata = rep.migration_metadata || {};
  let conclusionMigrationMetadata = existingMigrationMetadata.conclusion_migration;
  const recordUnknownFields = {
    ...(existingMigrationMetadata.unknown_fields || {})
  };

  const preserveUnknownField = (fieldPath, value) => {
    recordUnknownFields[fieldPath] = value;
    unknownFields.add(`Report.${fieldPath}`);
  };
  
  if (reportIds.has(repId)) {
    errorCount++;
    errors.push(`Duplicate report ID: "${repId}" at index ${repIdx}`);
  }
  reportIds.add(repId);

  // Track unknown keys on root
  Object.keys(rep).forEach(key => {
    if (!CANONICAL_REPORT_KEYS.has(key) && !KNOWN_LEGACY_REPORT_KEYS.has(key)) {
      preserveUnknownField(key, rep[key]);
    }
  });

  // Staff normalization
  const rawStaff = rep.staff || {};
  Object.keys(rawStaff).forEach(key => {
    if (!CANONICAL_STAFF_KEYS.has(key)) {
      preserveUnknownField(`staff.${key}`, rawStaff[key]);
    }
  });
  const staff = {
    name: rawStaff.name || '',
    nik: rawStaff.nik || ''
  };

  // Location normalization
  const rawLocation = rep.location || {};
  Object.keys(rawLocation).forEach(key => {
    if (!CANONICAL_LOCATION_KEYS.has(key) && !KNOWN_LEGACY_LOCATION_KEYS.has(key)) {
      preserveUnknownField(`location.${key}`, rawLocation[key]);
    }
  });
  const location = {
    site_id: rawLocation.site_id || rawLocation.siteId || '',
    site_name: rawLocation.site_name || rawLocation.siteName || '',
    area: rawLocation.area || '',
    detail_location: rawLocation.detail_location || rawLocation.detailLocation || ''
  };
  if (rawLocation.siteId !== undefined || rawLocation.siteName !== undefined || rawLocation.detailLocation !== undefined) {
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
      if (!CANONICAL_REVIEW_KEYS.has(key) && !KNOWN_LEGACY_REVIEW_KEYS.has(key)) {
        preserveUnknownField(`admin_review.${key}`, rawReview[key]);
      }
    });

    let conclusion = null;
    const rawConclusion = rawReview.conclusion;
    const conclusionKey = typeof rawConclusion === 'string'
      ? rawConclusion.trim().replace(/\s+/g, ' ').toUpperCase()
      : rawConclusion;
    if (conclusionKey === 'LULUS' || conclusionKey === 'PASSED') {
      conclusion = 'PASSED';
      if (rawConclusion !== 'PASSED') {
        warningCount++;
        warnings.push(`[Report: ${repId}] Normalizing legacy conclusion ${JSON.stringify(rawConclusion)} to "PASSED"`);
      }
    } else if (conclusionKey === 'TIDAK LULUS' || conclusionKey === 'NOT_PASSED') {
      conclusion = 'NOT_PASSED';
      if (rawConclusion !== 'NOT_PASSED') {
        warningCount++;
        warnings.push(`[Report: ${repId}] Normalizing legacy conclusion ${JSON.stringify(rawConclusion)} to "NOT_PASSED"`);
      }
    } else if (conclusionKey === 'FAILED' || conclusionKey === 'FAIL') {
      conclusion = 'NOT_PASSED';
      warningCount++;
      warnings.push(`[Report: ${repId}] Normalizing legacy conclusion ${JSON.stringify(rawConclusion)} to "NOT_PASSED"`);
    } else if (conclusionKey === 'NEEDS_FOLLOW_UP' || conclusionKey === 'NEED_FOLLOW_UP') {
      conclusion = 'NOT_PASSED';
      warningCount++;
      warnings.push(`[Report: ${repId}] Normalizing legacy conclusion ${JSON.stringify(rawConclusion)} to "NOT_PASSED"`);
    } else if (conclusionKey === 'BELUM LENGKAP' && ['DRAFT', 'SUBMITTED'].includes(reportStatus)) {
      conclusionMigrationMetadata = {
        original_value: String(rawConclusion),
        canonical_value: null,
        reason: 'UNFINISHED_REPORT',
        source_status: reportStatus
      };
      warningCount++;
      warnings.push(`[Report: ${repId}] Preserving unfinished legacy conclusion ${JSON.stringify(rawConclusion)} as null for ${reportStatus} report`);
    } else if (rawConclusion !== undefined && rawConclusion !== null) {
      errorCount++;
      errors.push(`[Report: ${repId}] Unsupported conclusion ${JSON.stringify(rawConclusion)} for report status ${reportStatus}; refusing to map it to null`);
    }

    admin_review = {
      admin_note: rawReview.admin_note || rawReview.adminNote || '',
      conclusion,
      reviewed_at: rawReview.reviewed_at || rawReview.reviewedAt || null,
      reviewed_by: rawReview.reviewed_by || rawReview.reviewedBy || null
    };

    if (rawReview.adminNote !== undefined || rawReview.reviewedAt !== undefined || rawReview.reviewedBy !== undefined) {
      warningCount++;
      warnings.push(`[Report: ${repId}] Using legacy property aliases in admin_review`);
    }
  }

  const requiresFinalConclusion = ['NEEDS_FOLLOW_UP', 'APPROVED'].includes(reportStatus);
  if (requiresFinalConclusion && (!admin_review || admin_review.conclusion === null)) {
    const rawReview = rep.admin_review || rep.adminReview;
    const diagnostic = {
      status: reportStatus,
      original_conclusion: rawReview?.conclusion ?? null,
      admin_review_present: Boolean(rawReview),
      checklist_item_count: (rep.checklist_items || rep.checklistItems || []).length
    };
    errorCount++;
    errors.push(`[Report: ${repId}] Final report is missing a valid conclusion; manual resolution required. Source preserved. Diagnostic: ${JSON.stringify(diagnostic)}`);
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
        preserveUnknownField(`checklist_items.${itemId}.${key}`, item[key]);
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
  const revision_history = existingMigrationMetadata.legacy_revision_history
    || rep.revision_history
    || rep.revisionHistory
    || [];
  const migration_metadata = {
    ...existingMigrationMetadata,
    legacy_revision_history: revision_history,
    ...(conclusionMigrationMetadata ? { conclusion_migration: conclusionMigrationMetadata } : {}),
    ...(Object.keys(recordUnknownFields).length > 0 ? { unknown_fields: recordUnknownFields } : {})
  };

  const normalized = {
    id: repId,
    type: rep.type || 'MATERIAL',
    template_id: rep.template_id || rep.templateId || '',
    form_code: rep.form_code || rep.formCode || '',
    title: rep.title || '',
    status: reportStatus,
    staff,
    location,
    general_info: rep.general_info || {},
    checklist_items,
    staff_note: rep.staff_note !== undefined ? rep.staff_note : (rep.staffNote || ''),
    submitted_at: rep.submitted_at || rep.submittedAt || null,
    admin_review,
    general_photos: rep.general_photos !== undefined ? rep.general_photos : (rep.generalPhotos || []),
    revision_number: rep.revision_number !== undefined
      ? rep.revision_number
      : (rep.revisionNumber !== undefined ? rep.revisionNumber : 1),
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
  if (rep.staffNote !== undefined) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property alias "staffNote"`);
  }
  if (rep.generalPhotos !== undefined) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property alias "generalPhotos"`);
  }
  if (rep.revisionNumber !== undefined) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property alias "revisionNumber"`);
  }
  if (rep.revisionHistory !== undefined) {
    warningCount++;
    warnings.push(`[Report: ${repId}] Using legacy property alias "revisionHistory"`);
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
console.log(`Quarantined records: ${quarantinedReports.length}`);
console.log(`Warnings generated: ${warningCount}`);
console.log(`Errors encountered: ${errorCount}`);

if (quarantinedReports.length > 0) {
  console.log('Quarantined record details:');
  quarantinedReports.forEach(entry => {
    console.log(` - ${entry.record.id}: ${entry.reason} [${entry.disposition}]`);
  });
}

if (unknownFields.size > 0) {
  console.log('Unknown fields detected (preserved in migration_metadata.unknown_fields):');
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

// Atomic output writes
const outputTargets = [
  { outputPath, data: normalizedReports, label: 'normalized reports' },
  ...(quarantineManifestPath
    ? [{ outputPath: quarantineOutputPath, data: quarantinedReports, label: 'quarantined reports' }]
    : [])
];
const tempTargets = outputTargets.map((target, index) => ({
  ...target,
  tempPath: `${target.outputPath}.${Date.now()}.${index}.tmp`
}));
try {
  tempTargets.forEach(target => {
    const dir = path.dirname(target.outputPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(target.tempPath, JSON.stringify(target.data, null, 2), 'utf8');
  });
  tempTargets.forEach(target => fs.renameSync(target.tempPath, target.outputPath));
  tempTargets.forEach(target => console.log(`\nSuccessfully wrote ${target.label} to ${target.outputPath}`));
  process.exit(0);
} catch (e) {
  tempTargets.forEach(target => {
    try {
      if (fs.existsSync(target.tempPath)) fs.unlinkSync(target.tempPath);
    } catch (_) {}
  });
  console.error(`\nFailed to write migration output file: ${e.message}`);
  process.exit(1);
}
