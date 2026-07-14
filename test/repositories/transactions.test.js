const test = require('node:test');
const assert = require('node:assert/strict');
const { PostgresTemplateRepository } = require('../../src/repositories/postgres-template.repository');
const { PostgresReportRepository } = require('../../src/repositories/postgres-report.repository');

class FailingPool {
  constructor(failPattern) {
    this.failPattern = failPattern;
    this.commands = [];
    this.released = false;
    this.client = {
      query: async text => {
        this.commands.push(text.trim().split(/\s+/).slice(0, 4).join(' '));
        if (text.includes(this.failPattern)) throw new Error('forced child write failure');
        return { rows: [], rowCount: 0 };
      },
      release: () => { this.released = true; }
    };
  }

  async connect() {
    return this.client;
  }
}

test('template aggregate write rolls back when an item write fails', async () => {
  const pool = new FailingPool('insert into public.qc_template_items');
  const repository = new PostgresTemplateRepository(pool);
  await assert.rejects(repository.create({
    id: 'MAT-ROLLBACK', type: 'MATERIAL', name: 'Rollback',
    checklist_items: [{
      id: 'I-1', parameter_name: 'Value', input_type: 'text', is_required: true,
      required_photo: false
    }]
  }), /forced child write failure/);
  assert.equal(pool.commands[0], 'BEGIN');
  assert.equal(pool.commands.at(-1), 'ROLLBACK');
  assert.equal(pool.commands.includes('COMMIT'), false);
  assert.equal(pool.released, true);
});

test('report aggregate write rolls back when an item write fails', async () => {
  const pool = new FailingPool('insert into public.qc_report_items');
  const repository = new PostgresReportRepository(pool);
  await assert.rejects(repository.create({
    id: 'QC-ROLLBACK', type: 'MATERIAL', title: 'Rollback', status: 'DRAFT',
    staff: { name: '', nik: '' }, location: {}, checklist_items: [{
      id: 'I-1', parameter_name: 'Value', input_type: 'text'
    }]
  }), /forced child write failure/);
  assert.equal(pool.commands[0], 'BEGIN');
  assert.equal(pool.commands.at(-1), 'ROLLBACK');
  assert.equal(pool.commands.includes('COMMIT'), false);
  assert.equal(pool.released, true);
});

test('successful aggregate transaction commits and releases its client', async () => {
  const pool = new FailingPool('never');
  const repository = new PostgresTemplateRepository(pool);
  const result = await repository._transaction(async client => {
    await client.query('select 1');
    return 'committed';
  });
  assert.equal(result, 'committed');
  assert.deepEqual(pool.commands, ['BEGIN', 'select 1', 'COMMIT']);
  assert.equal(pool.released, true);
});

test('PostgreSQL implementations expose the shared repository methods', () => {
  const pool = new FailingPool('never');
  const templates = new PostgresTemplateRepository(pool);
  const reports = new PostgresReportRepository(pool);
  for (const method of ['findAll', 'findById', 'create', 'update']) {
    assert.equal(typeof templates[method], 'function');
    assert.equal(typeof reports[method], 'function');
  }
  assert.equal(typeof templates.deleteChecklistItem, 'function');
});
