const test = require('node:test');
const assert = require('node:assert/strict');
const { PostgresTemplateRepository } = require('../../src/repositories/postgres-template.repository');
const { canonicalTemplateItemInput } = require('../../src/repositories/postgres/mappers');

const numberItem = canonicalTemplateItemInput({
  id: 'N-1', parameter_name: 'Length', input_type: 'number', standard_text: '4.2',
  min_value: null, max_value: null, unit: 'mm', is_required: true, required_photo: false
});

const choiceOptions = [
  { id: 'pass', label: 'Sesuai', value: 'PASS', outcome: 'PASS', position: 0 },
  { id: 'fail', label: 'Tidak Sesuai', value: 'FAIL', outcome: 'FAIL', position: 1 }
];

const choiceItem = canonicalTemplateItemInput({
  id: 'C-1', parameter_name: 'Condition', input_type: 'choice', standard_text: 'Select',
  choice_options: choiceOptions, is_required: true, required_photo: false
});

const captureInsert = async item => {
  let captured;
  const client = {
    query: async (text, parameters) => {
      captured = { text, parameters };
      return { rows: [], rowCount: 1 };
    }
  };
  await new PostgresTemplateRepository({})._insertItems(client, 'MAT-1', [item]);
  return captured;
};

const capturePatch = async (current, patch) => {
  const queries = [];
  const client = {
    query: async (text, parameters) => {
      queries.push({ text, parameters });
      return { rows: [], rowCount: 1 };
    }
  };
  const repository = new PostgresTemplateRepository({});
  repository._transaction = work => work(client);
  repository._findById = async () => ({ checklist_items: [current] });
  repository._findItem = async () => current;
  await repository.updateChecklistItem('MAT-1', current.id, patch);
  return queries.find(query => query.text.includes('update public.qc_template_items set'));
};

const assertJsonArrayBinding = (query, expected) => {
  assert.match(query.text, /choice_options=\$15::jsonb|\$15::jsonb/);
  assert.equal(typeof query.parameters[14], 'string');
  const decoded = JSON.parse(query.parameters[14]);
  assert.equal(Array.isArray(decoded), true);
  assert.deepEqual(decoded, expected);
};

test('PostgreSQL INSERT binds empty choice_options as JSONB array JSON', async () => {
  assertJsonArrayBinding(await captureInsert(numberItem), []);
});

test('PostgreSQL INSERT binds structured choice_options as JSONB array JSON', async () => {
  assertJsonArrayBinding(await captureInsert(choiceItem), choiceOptions);
});

test('PostgreSQL PATCH choice to number binds cleared choice_options as JSONB []', async () => {
  const query = await capturePatch(choiceItem, { input_type: 'number', standard_text: '4.2', unit: 'mm' });
  assertJsonArrayBinding(query, []);
});

test('PostgreSQL PATCH number to choice binds structured choice_options as JSONB array JSON', async () => {
  const query = await capturePatch(numberItem, {
    input_type: 'choice', standard_text: 'Select', choice_options: choiceOptions
  });
  assertJsonArrayBinding(query, choiceOptions);
});
