/**
 * Deterministic request fingerprint for report create idempotency.
 *
 * Computes SHA-256 over the full canonical semantic payload that determines
 * the logical identity of a report creation:
 * - All persisted user-supplied fields (id, template, form, staff, location,
 *   checklist_items, samples, answers, evidence paths, notes, etc.)
 *
 * Excluded (server-computed or transport-only):
 * - template_snapshot: server-resolved from template_id; must not affect fingerprint
 * - server-generated timestamps (created_at, updated_at) added by the DB layer
 * - migration_metadata: internal backfill field, not from this submission
 *
 * Key ordering is sorted recursively so that object key insertion order does
 * not affect the fingerprint. Arrays are preserved in their submitted order
 * because sequence has logical meaning for items/samples/answers.
 */

const crypto = require('crypto');

/**
 * Recursively sort object keys. Arrays are preserved in order.
 * @param {*} value
 * @returns {*}
 */
function sortedKeys(value) {
  if (Array.isArray(value)) {
    return value.map(sortedKeys);
  }
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map(k => [k, sortedKeys(value[k])])
    );
  }
  return value;
}

/**
 * Extract the canonical semantic fields from a normalized report input.
 * This runs AFTER canonicalReportInput() has been applied, so field names
 * are already snake_case and defaults have been applied.
 *
 * @param {object} report — output of canonicalReportInput()
 * @returns {object} canonical fingerprint payload
 */
function canonicalFingerprintPayload(report) {
  return {
    id: report.id,
    type: report.type,
    template_id: report.template_id,
    form_code: report.form_code,
    title: report.title,
    status: report.status,
    staff: report.staff,
    location: report.location,
    general_info: report.general_info,
    staff_note: report.staff_note,
    submitted_at: report.submitted_at,
    revision_number: report.revision_number,
    sample_count: report.sample_count,
    general_photos: report.general_photos,
    admin_review: report.admin_review,
    // Checklist items including answers, photos, and evaluation fields
    checklist_items: (report.checklist_items || []).map(item => ({
      id: item.id,
      parameter_name: item.parameter_name,
      input_type: item.input_type,
      standard_text: item.standard_text,
      unit: item.unit,
      actual_value: item.actual_value,
      staff_note: item.staff_note,
      item_photos: item.item_photos,
      admin_evaluation: item.admin_evaluation,
      admin_note: item.admin_note
    })),
    // Samples with answers and evidence
    samples: (report.samples || []).map(sample => ({
      id: sample.id,
      sample_number: sample.sample_number,
      inspection_status: sample.inspection_status,
      notes: sample.notes,
      photo_paths: sample.photo_paths,
      checklist_answers: (sample.checklist_answers || []).map(answer => ({
        checklist_item_id: answer.checklist_item_id,
        input_type: answer.input_type,
        actual_value: answer.actual_value,
        note: answer.note,
        photo_paths: answer.photo_paths,
        standard_text: answer.standard_text,
        standard_value: answer.standard_value,
        unit: answer.unit,
        upper_tolerance: answer.upper_tolerance,
        lower_tolerance: answer.lower_tolerance,
        minimum_value: answer.minimum_value,
        maximum_value: answer.maximum_value,
        evaluation_status: answer.evaluation_status,
        admin_evaluation: answer.admin_evaluation,
        admin_note: answer.admin_note
      }))
    })),
    // Review request fields
    review_requested: report.review_requested,
    review_requested_at: report.review_requested_at,
    review_requested_by_role: report.review_requested_by_role,
    review_failed_sample_count: report.review_failed_sample_count,
    review_failed_sample_ids: report.review_failed_sample_ids,
    review_failed_sample_numbers: report.review_failed_sample_numbers
    // Excluded: template_snapshot, migration_metadata, created_at, updated_at
  };
}

/**
 * Compute SHA-256 fingerprint of the canonical report create payload.
 * Same semantic payload with different object key order => same fingerprint.
 * Different checklist/sample/answer data => different fingerprint.
 *
 * @param {object} canonicalReport — output of canonicalReportInput()
 * @returns {string} hex SHA-256 digest
 */
function fingerprintReportCreate(canonicalReport) {
  const payload = canonicalFingerprintPayload(canonicalReport);
  const sorted = sortedKeys(payload);
  const serialized = JSON.stringify(sorted);
  return crypto.createHash('sha256').update(serialized, 'utf8').digest('hex');
}

module.exports = { fingerprintReportCreate, canonicalFingerprintPayload, sortedKeys };
