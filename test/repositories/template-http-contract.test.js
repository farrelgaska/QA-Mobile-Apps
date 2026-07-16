const test = require('node:test');
const assert = require('node:assert/strict');

process.env.DATA_PROVIDER = 'json';
delete process.env.VERCEL;

const repositories = require('../../src/repositories');
const { canonicalTemplateInput } = require('../../src/repositories/postgres/mappers');
let stored;

repositories.templateRepository.create = async input => {
  stored = canonicalTemplateInput(input);
  return stored;
};
repositories.templateRepository.update = async (id, patch) => {
  const merged = { ...stored, ...patch, id };
  if (patch.checklistItems !== undefined && patch.checklist_items === undefined) {
    merged.checklist_items = patch.checklistItems;
  }
  stored = canonicalTemplateInput(merged);
  return stored;
};

const app = require('../../src/app');

const request = async (baseUrl, path, method, body) => fetch(`${baseUrl}${path}`, {
  method,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body)
});

test('template routes emit snake_case, preserve items on metadata PATCH, and reject invalid choices', async t => {
  const server = app.listen(0);
  t.after(() => server.close());
  await new Promise(resolve => server.once('listening', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const createdResponse = await request(baseUrl, '/templates', 'POST', {
    id: 'MAT-HTTP-CONTRACT',
    type: 'MATERIAL',
    name: 'HTTP contract',
    checklistItems: [{
      id: 'N-1', parameterName: 'Length', inputType: 'number', standardText: '4.2',
      minValue: 4, maxValue: 5, required: true, requiredPhoto: false
    }]
  });
  assert.equal(createdResponse.status, 201);
  const created = await createdResponse.json();
  assert.equal(created.checklist_items[0].parameter_name, 'Length');
  assert.equal('checklistItems' in created, false);

  const patchedResponse = await request(baseUrl, '/templates/MAT-HTTP-CONTRACT', 'PATCH', {
    name: 'Renamed',
    is_active: false
  });
  assert.equal(patchedResponse.status, 200);
  const patched = await patchedResponse.json();
  assert.equal(patched.is_active, false);
  assert.equal(patched.checklist_items.length, 1);

  const originalConsoleError = console.error;
  console.error = () => {};
  try {
    const invalidResponse = await request(baseUrl, '/templates/MAT-HTTP-CONTRACT', 'PATCH', {
      checklist_items: [{
        id: 'C-1', parameter_name: 'Condition', input_type: 'choice', standard_text: '',
        is_required: true, required_photo: false,
        choice_options: [{ id: 'ok', label: '', value: 'ok', outcome: 'PASS', position: 0 }]
      }]
    });
    assert.equal(invalidResponse.status, 400);
    assert.match((await invalidResponse.json()).error, /label|FAIL option/);
  } finally {
    console.error = originalConsoleError;
  }
});
