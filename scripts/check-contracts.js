const { templateSchema } = require('../src/contracts/template.contract');
const { reportSchema } = require('../src/contracts/report.contract');

console.log('Validating Zod contract schemas...');

// 1. Validate a mock template
const mockTemplate = {
  id: "test_temp_id",
  type: "MATERIAL",
  name: "Test Template",
  description: "Test Description",
  form_code: "FORM-TEST",
  category: "Test Cat",
  segment: "construction",
  standard_code: "STD-123",
  is_active: true,
  version: 1,
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
  checklist_items: [
    {
      id: "item-1",
      parameter_name: "Thickness",
      input_type: "number",
      standard_text: ">= 5mm",
      unit: "mm",
      is_required: true,
      required_photo: false,
      is_active: true,
      is_critical: true,
      position: 1,
      choices: [],
      validation_rule: {
        type: "range",
        min_value: 5,
        max_value: 10,
        exact_value: null
      }
    }
  ]
};

try {
  templateSchema.parse(mockTemplate);
  console.log('[PASS] templateSchema parsed mockTemplate successfully!');
} catch (e) {
  console.error('[FAIL] templateSchema failed to parse mockTemplate:', e.message);
  process.exit(1);
}

// 2. Validate a mock report
const mockReport = {
  id: "QC-REP-123",
  type: "MATERIAL",
  template_id: "test_temp_id",
  form_code: "FORM-TEST",
  title: "Test Report",
  status: "SUBMITTED",
  staff: {
    name: "Staff Name",
    nik: "NIK-123"
  },
  location: {
    site_id: "site-123",
    site_name: "Site A",
    area: "Zone B",
    detail_location: "Corner"
  },
  general_info: {},
  checklist_items: [
    {
      id: "item-1",
      parameter_name: "Thickness",
      input_type: "number",
      standard_text: ">= 5mm",
      unit: "mm",
      actual_value: "6",
      staff_note: "Looks good",
      item_photos: [],
      admin_evaluation: "PASS",
      admin_note: ""
    }
  ],
  staff_note: "Done",
  submitted_at: new Date().toISOString(),
  admin_review: {
    admin_note: "Reviewing...",
    conclusion: "PASSED",
    reviewed_at: new Date().toISOString()
  },
  general_photos: [],
  revision_number: 1,
  migration_metadata: {
    legacy_revision_history: []
  }
};

try {
  reportSchema.parse(mockReport);
  console.log('[PASS] reportSchema parsed mockReport successfully!');
} catch (e) {
  console.error('[FAIL] reportSchema failed to parse mockReport:', e.message);
  process.exit(1);
}

console.log('All Zod contracts check passed successfully!');
process.exit(0);
