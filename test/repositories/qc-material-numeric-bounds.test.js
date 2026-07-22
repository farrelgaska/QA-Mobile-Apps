const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { deriveQcMaterialNumericBounds } = require('../../src/contracts/qc-material-numeric-bounds');
const { canonicalTemplateItemInput, mapTemplateItemRow } = require('../../src/repositories/postgres/mappers');
const { auditQcMaterialNumericBounds } = require('../../scripts/audit-qc-material-numeric-bounds');

const assertClose = (actual, expected) => {
  assert.ok(Math.abs(actual - expected) < 1e-10, `expected ${actual} to be close to ${expected}`);
};

test('derives recognized absolute and percentage tolerance bounds', () => {
  assert.deepEqual(deriveQcMaterialNumericBounds('7000 ± 40 mm'), {
    validationType: 'RANGE',
    minValue: 6960,
    maxValue: 7040,
    format: 'ABSOLUTE_TOLERANCE'
  });

  const decimalTolerance = deriveQcMaterialNumericBounds('114,3 ± 2,9 mm');
  assert.equal(decimalTolerance.validationType, 'RANGE');
  assertClose(decimalTolerance.minValue, 111.4);
  assertClose(decimalTolerance.maxValue, 117.2);

  const symmetricPercentage = deriveQcMaterialNumericBounds('76,3 mm ± 1%');
  assertClose(symmetricPercentage.minValue, 75.537);
  assertClose(symmetricPercentage.maxValue, 77.063);

  const asymmetricPercentage = deriveQcMaterialNumericBounds('4 mm +15% -12,5%');
  assertClose(asymmetricPercentage.minValue, 3.5);
  assertClose(asymmetricPercentage.maxValue, 4.6);
});

test('derives explicit ranges, explicit minimums, and validation-qualified exact values', () => {
  assert.deepEqual(deriveQcMaterialNumericBounds('122 - 128 mm'), {
    validationType: 'RANGE',
    minValue: 122,
    maxValue: 128,
    format: 'EXPLICIT_RANGE'
  });
  assert.deepEqual(deriveQcMaterialNumericBounds('≥ 52,5 kg'), {
    validationType: 'MIN',
    minValue: 52.5,
    maxValue: null,
    format: 'EXPLICIT_MINIMUM'
  });
  assert.deepEqual(deriveQcMaterialNumericBounds('Minimal 43,78 kg'), {
    validationType: 'MIN',
    minValue: 43.78,
    maxValue: null,
    format: 'EXPLICIT_MINIMUM'
  });
  assert.deepEqual(deriveQcMaterialNumericBounds('0,25 m', 'EXACT'), {
    validationType: 'EXACT',
    minValue: 0.25,
    maxValue: 0.25,
    format: 'VALIDATION_QUALIFIED_EXACT'
  });
});

test('does not guess plain minimums or unsupported standards', () => {
  assert.equal(deriveQcMaterialNumericBounds('40 cm', 'MIN'), null);
  assert.equal(deriveQcMaterialNumericBounds('120 kg', 'MIN'), null);
  assert.equal(deriveQcMaterialNumericBounds('approximately 3 mm', 'RANGE'), null);
  assert.equal(deriveQcMaterialNumericBounds('128 - 122 mm', 'RANGE'), null);
});

test('audit reports supported update candidates and exact unsupported identity', () => {
  const result = auditQcMaterialNumericBounds([
    {
      template_id: 'material-a', item_id: 'item-a', standard_text: '7000 ± 40 mm', validation_type: 'RANGE',
      min_value: null, max_value: null, validation_min_value: null, validation_max_value: null
    },
    {
      template_id: 'material-a', item_id: 'item-b', standard_text: '40 cm', validation_type: 'MIN',
      min_value: null, max_value: null, validation_min_value: null, validation_max_value: null
    }
  ]);

  assert.equal(result.numeric_material_items, 2);
  assert.equal(result.supported_items, 1);
  assert.equal(result.would_update, 1);
  assert.deepEqual(result.unsupported, [{
    template_id: 'material-a',
    item_id: 'item-b',
    standard_text: '40 cm'
  }]);
});

test('repository contracts expose structured bounds without changing standard text', () => {
  const standardText = '7000 ± 40 mm';
  const input = canonicalTemplateItemInput({
    id: 'item-a',
    parameter_name: 'Panjang',
    input_type: 'number',
    standard_text: standardText,
    min_value: 6960,
    max_value: 7040,
    validation_rule: { type: 'RANGE', min_value: 6960, max_value: 7040, exact_value: null }
  });
  assert.equal(input.standard_text, standardText);
  assert.equal(input.min_value, 6960);
  assert.equal(input.max_value, 7040);

  const mapped = mapTemplateItemRow({
    id: 'item-a', parameter_name: 'Panjang', input_type: 'number', standard_text: standardText,
    min_value: '6960', max_value: '7040', unit: 'mm', is_required: true, required_photo: false,
    is_active: true, is_critical: false, position: 1, choices: [], choice_options: [], category: '',
    validation_type: 'RANGE', validation_min_value: '6960', validation_max_value: '7040',
    validation_exact_value: null, migration_metadata: null
  });
  assert.equal(mapped.standard_text, standardText);
  assert.deepEqual(mapped.validation_rule, {
    type: 'RANGE', min_value: 6960, max_value: 7040, exact_value: null
  });
});

test('migration updates only structured columns and contains unsupported reporting', () => {
  const migrationPath = path.join(
    __dirname,
    '../../supabase/migrations/20260722000100_backfill_qc_material_numeric_bounds.sql'
  );
  const migration = fs.readFileSync(migrationPath, 'utf8');
  assert.match(migration, /set\s+min_value\s*=/i);
  assert.match(migration, /validation_min_value\s*=/i);
  assert.match(migration, /validation_max_value\s*=/i);
  assert.doesNotMatch(migration, /set\s+standard_text\s*=/i);
  assert.match(migration, /unsupported/i);
});
