const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const templateModule = require('../../src/repositories/json-template.repository');
const { checklistItemSchema, templateSchema } = require('../../src/contracts/template.contract');
const { canonicalTemplateInput, mapTemplateAggregate } = require('../../src/repositories/postgres/mappers');

const baseTemplate = item => ({
  id: 'MAT-CONTRACT',
  type: 'MATERIAL',
  name: 'Contract',
  checklist_items: [item]
});

const textItem = {
  id: 'TEXT-1',
  parameter_name: 'Description',
  input_type: 'text',
  standard_text: 'Describe the result',
  is_required: true,
  required_photo: false
};

const booleanItem = {
  ...textItem,
  id: 'BOOLEAN-1',
  parameter_name: 'Condition acceptable',
  input_type: 'boolean',
  min_value: null,
  max_value: null,
  choices: [],
  choice_options: [],
  validation_rule: {
    type: 'BOOLEANREQUIRED',
    min_value: null,
    max_value: null,
    exact_value: true
  }
};

test('canonical boolean items accept empty bounds and choices with BOOLEANREQUIRED metadata', () => {
  const parsed = checklistItemSchema.parse(booleanItem);

  assert.equal(parsed.input_type, 'boolean');
  assert.equal(parsed.validation_rule.type, 'BOOLEANREQUIRED');
  assert.equal(parsed.validation_rule.exact_value, true);
});

test('normalized legacy booleanCheck templates pass templateSchema', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'template-boolean-normalization-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const input = path.join(directory, 'legacy.json');
  const output = path.join(directory, 'canonical.json');
  fs.writeFileSync(input, JSON.stringify([{
    id: 'legacy-boolean',
    type: 'MATERIAL',
    name: 'Legacy boolean',
    is_active: true,
    checklist_items: [{
      id: 'boolean-1',
      parameter_name: 'Condition acceptable',
      inputType: 'booleanCheck',
      minVal: 0,
      maxVal: 1,
      choices: ['PASS', 'FAIL'],
      choiceOptions: [
        { id: 'yes', label: 'Yes', value: 'yes', outcome: 'PASS', position: 0 }
      ],
      is_required: true,
      required_photo: false,
      is_active: true,
      validation_rule: { type: 'BOOLEANREQUIRED', exact_value: true }
    }]
  }]));

  const result = spawnSync(
    process.execPath,
    [path.join(__dirname, '../../scripts/normalize-templates.js'), '--input', input, '--output', output],
    { encoding: 'utf8' }
  );

  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  const [normalized] = JSON.parse(fs.readFileSync(output, 'utf8'));
  const [normalizedItem] = normalized.checklist_items;
  assert.equal(normalizedItem.input_type, 'boolean');
  assert.equal(normalizedItem.min_value, null);
  assert.equal(normalizedItem.max_value, null);
  assert.deepEqual(normalizedItem.choices, []);
  assert.deepEqual(normalizedItem.choice_options, []);
  assert.equal(normalizedItem.validation_rule.type, 'BOOLEANREQUIRED');
  assert.equal(normalizedItem.validation_rule.exact_value, true);
  assert.match(result.stdout, /Discarding numeric bounds from boolean item/);
  assert.match(result.stdout, /Discarding legacy choices from boolean item/);
  assert.match(result.stdout, /Discarding structured choice_options from boolean item/);
  assert.doesNotThrow(() => templateSchema.parse(normalized));
});

test('boolean items reject numeric bounds', () => {
  assert.throws(
    () => checklistItemSchema.parse({ ...booleanItem, min_value: 1 }),
    /boolean items cannot define numeric bounds/
  );
});

test('boolean items reject legacy choices', () => {
  assert.throws(
    () => checklistItemSchema.parse({ ...booleanItem, choices: ['PASS', 'FAIL'] }),
    /boolean items cannot define choices/
  );
});

test('boolean items reject structured choice options', () => {
  assert.throws(
    () => checklistItemSchema.parse({
      ...booleanItem,
      choice_options: [
        { id: 'yes', label: 'Yes', value: 'yes', outcome: 'PASS', position: 0 }
      ]
    }),
    /boolean items cannot define choices/
  );
});

test('PostgreSQL rows emit the snake_case checklist contract', () => {
  const result = mapTemplateAggregate({
    id: 'MAT-1', type: 'MATERIAL', name: 'Material', description: '', form_code: '',
    category: '', segment: 'construction', standard_code: '', is_active: true,
    workflow_status: null, version: 1, created_at: new Date(), updated_at: new Date()
  }, [{
    id: 'N-1', parameter_name: 'Length', input_type: 'number', standard_text: '4.2',
    min_value: '4', max_value: '5', unit: 'm', choice_options: [], choices: [],
    is_required: true, required_photo: false, is_active: true, is_critical: false,
    position: 0, category: '', validation_type: null, validation_min_value: null,
    validation_max_value: null, validation_exact_value: null
  }]);

  assert.deepEqual(Object.keys(result.checklist_items[0]).slice(0, 12), [
    'id', 'parameter_name', 'input_type', 'standard_text', 'min_value', 'max_value',
    'unit', 'is_required', 'required_photo', 'is_active', 'is_critical', 'position'
  ]);
  assert.equal(result.checklist_items[0].min_value, 4);
  assert.deepEqual(result.checklist_items[0].choice_options, []);
});

test('camelCase writes normalize to snake_case and keep required flags separate', () => {
  const result = canonicalTemplateInput({
    id: 'MAT-ALIAS', type: 'MATERIAL', name: 'Alias', isActive: false,
    checklistItems: [{
      id: 'N-1', parameterName: 'Length', inputType: 'number', standardText: 4.2,
      minValue: 4, maxValue: 5, unit: 'm', required: false, requiredPhoto: true
    }]
  });
  assert.equal(result.is_active, false);
  assert.equal(result.checklist_items[0].standard_text, '4.2');
  assert.equal(result.checklist_items[0].is_required, false);
  assert.equal(result.checklist_items[0].required_photo, true);
  assert.equal('checklistItems' in result, false);
});

test('number bounds accept nullable values and reject reversed ranges', () => {
  assert.doesNotThrow(() => canonicalTemplateInput(baseTemplate({
    ...textItem, id: 'N-1', input_type: 'number', min_value: null, max_value: 4.2
  })));
  assert.throws(() => canonicalTemplateInput(baseTemplate({
    ...textItem, id: 'N-1', input_type: 'number', min_value: 5, max_value: 4
  })), /min_value must be less than or equal/);
});

test('structured choices require complete ordered PASS and FAIL options', () => {
  const valid = baseTemplate({
    ...textItem,
    id: 'C-1',
    input_type: 'choice',
    choice_options: [
      { id: 'yes', label: 'Sesuai', value: 'yes', outcome: 'PASS', position: 0 },
      { id: 'no', label: 'Tidak sesuai', value: 'no', outcome: 'FAIL', position: 1 }
    ]
  });
  assert.deepEqual(canonicalTemplateInput(valid).checklist_items[0].choice_options, valid.checklist_items[0].choice_options);
  assert.throws(() => canonicalTemplateInput(baseTemplate({
    ...valid.checklist_items[0],
    choice_options: [{ id: 'yes', label: '', value: 'yes', outcome: 'PASS', position: 0 }]
  })), /Too small|empty|FAIL option/);
});

test('JSON metadata PATCH preserves checklist items and emits snake_case', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'template-contract-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const file = path.join(directory, 'templates.json');
  fs.writeFileSync(file, '[]');
  const repository = new templateModule.JsonTemplateRepository(file);
  repository.create(baseTemplate(textItem));

  const updated = repository.update('MAT-CONTRACT', { name: 'Renamed', isActive: false });
  assert.equal(updated.name, 'Renamed');
  assert.equal(updated.is_active, false);
  assert.equal(updated.checklist_items.length, 1);
  assert.equal(updated.checklist_items[0].parameter_name, 'Description');
});

test('JSON metadata PATCH preserves legacy choices that predate structured options', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'template-legacy-contract-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const file = path.join(directory, 'templates.json');
  fs.writeFileSync(file, JSON.stringify([{
    id: 'MAT-LEGACY', type: 'MATERIAL', name: 'Legacy', checklistItems: [{
      id: 'C-1', parameterName: 'Condition', inputType: 'choice', standardText: '',
      required: true, requiredPhoto: false, choices: []
    }]
  }]));
  const repository = new templateModule.JsonTemplateRepository(file);

  const updated = repository.update('MAT-LEGACY', { is_active: false });
  assert.equal(updated.is_active, false);
  assert.equal(updated.checklist_items.length, 1);
  assert.deepEqual(updated.checklist_items[0].choice_options, []);
});

test('text items reject bounds and choices consistently', () => {
  assert.throws(() => canonicalTemplateInput(baseTemplate({ ...textItem, min_value: 1 })), /text items cannot define numeric bounds/);
  assert.throws(() => canonicalTemplateInput(baseTemplate({ ...textItem, choices: ['x'] })), /text items cannot define choices/);
});

test('JSON item create generates stable IDs and next positions without replacing siblings', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'template-item-create-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const file = path.join(directory, 'templates.json');
  fs.writeFileSync(file, '[]');
  const repository = new templateModule.JsonTemplateRepository(file);
  repository.create(baseTemplate(textItem));

  const created = repository.createChecklistItem('MAT-CONTRACT', {
    parameterName: 'Length', inputType: 'number', standardText: '4.2',
    minValue: 4, maxValue: 5, unit: 'mm', isRequired: true, requiredPhoto: true
  });
  assert.equal(created.id, 'MAT-CONTRACT-C01');
  assert.equal(created.position, 1);
  assert.equal(created.parameter_name, 'Length');
  assert.equal(created.min_value, 4);
  assert.equal(repository.findById('MAT-CONTRACT').checklist_items.length, 2);
  assert.throws(
    () => repository.createChecklistItem('MAT-CONTRACT', { ...created, position: 2 }),
    error => error.statusCode === 409
  );
});

test('JSON item PATCH merges fields, keeps IDs immutable, and clears fields on type changes', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'template-item-update-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const file = path.join(directory, 'templates.json');
  fs.writeFileSync(file, '[]');
  const repository = new templateModule.JsonTemplateRepository(file);
  repository.create(baseTemplate({
    ...textItem, id: 'N-1', input_type: 'number', min_value: 4, max_value: 5, unit: 'mm'
  }));

  const updated = repository.updateChecklistItem('MAT-CONTRACT', 'N-1', {
    id: 'CHANGED', inputType: 'text', standardText: 'Visual description', requiredPhoto: true
  });
  assert.equal(updated.id, 'N-1');
  assert.equal(updated.input_type, 'text');
  assert.equal(updated.standard_text, 'Visual description');
  assert.equal(updated.min_value, null);
  assert.equal(updated.max_value, null);
  assert.equal(updated.unit, null);
  assert.deepEqual(updated.choice_options, []);
  assert.equal(updated.required_photo, true);
  assert.throws(
    () => repository.updateChecklistItem('MAT-CONTRACT', 'MISSING', { standard_text: 'x' }),
    error => error.statusCode === 404
  );
});
