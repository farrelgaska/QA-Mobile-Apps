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

class DeletePool {
  constructor() {
    this.commands = [];
    this.client = {
      query: async (text, parameters = []) => {
        this.commands.push(text.trim().split(/\s+/).slice(0, 5).join(' '));
        if (text.startsWith('delete from public.')) {
          return { rows: parameters[0].includes('MISSING') ? [] : [{ id: parameters[0] }], rowCount: parameters[0].includes('MISSING') ? 0 : 1 };
        }
        return { rows: [], rowCount: 0 };
      },
      release: () => {}
    };
  }

  async connect() { return this.client; }
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

test('staff report creation does not insert a placeholder admin review', async () => {
  const pool = new FailingPool('never');
  const repository = new PostgresReportRepository(pool);

  await repository.create({
    id: 'QC-MAT-2026-1009', type: 'MATERIAL', title: 'Staff report', status: 'SUBMITTED',
    staff: { name: 'QA Staff', nik: 'QA-1' }, location: {}, checklist_items: [],
    adminReview: { reviewedBy: '', conclusion: 'Belum Lengkap', adminNote: '' }
  });

  assert.equal(
    pool.commands.some(command => command.startsWith('insert into public.qc_report_admin_reviews')),
    false
  );
  assert.equal(pool.commands[0], 'BEGIN');
  assert.equal(pool.commands.at(-1), 'COMMIT');
  assert.equal(pool.released, true);
});

test('genuine canonical admin review continues to persist', async () => {
  const pool = new FailingPool('never');
  const repository = new PostgresReportRepository(pool);

  await repository.create({
    id: 'QC-ADMIN-REVIEW', type: 'MATERIAL', title: 'Reviewed report', status: 'APPROVED',
    staff: { name: 'QA Staff', nik: 'QA-1' }, location: {}, checklist_items: [],
    admin_review: { reviewed_by: 'Admin One', conclusion: 'PASSED', admin_note: 'Accepted' }
  });

  assert.equal(
    pool.commands.some(command => command.startsWith('insert into public.qc_report_admin_reviews')),
    true
  );
  assert.equal(pool.commands.at(-1), 'COMMIT');
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

test('PostgreSQL aggregate deletes commit after deleting only the parent row', async () => {
  const templatePool = new DeletePool();
  const reportPool = new DeletePool();
  await new PostgresTemplateRepository(templatePool).delete('MAT-DELETE');
  await new PostgresReportRepository(reportPool).delete('QC-DELETE');
  assert.deepEqual(templatePool.commands, [
    'BEGIN', 'delete from public.qc_templates where id', 'COMMIT'
  ]);
  assert.deepEqual(reportPool.commands, [
    'BEGIN', 'delete from public.qc_reports where id', 'COMMIT'
  ]);
});

test('PostgreSQL aggregate deletes roll back and return 404 for missing IDs', async () => {
  const templatePool = new DeletePool();
  const reportPool = new DeletePool();
  await assert.rejects(
    new PostgresTemplateRepository(templatePool).delete('MAT-MISSING'),
    error => error.statusCode === 404
  );
  await assert.rejects(
    new PostgresReportRepository(reportPool).delete('QC-MISSING'),
    error => error.statusCode === 404
  );
  assert.equal(templatePool.commands.at(-1), 'ROLLBACK');
  assert.equal(reportPool.commands.at(-1), 'ROLLBACK');
});

test('PostgreSQL implementations expose the shared repository methods', () => {
  const pool = new FailingPool('never');
  const templates = new PostgresTemplateRepository(pool);
  const reports = new PostgresReportRepository(pool);
  for (const method of ['findAll', 'findById', 'create', 'update', 'delete']) {
    assert.equal(typeof templates[method], 'function');
    assert.equal(typeof reports[method], 'function');
  }
  assert.equal(typeof templates.deleteChecklistItem, 'function');
  assert.equal(typeof templates.createChecklistItem, 'function');
  assert.equal(typeof templates.updateChecklistItem, 'function');
});
