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
        if (text.startsWith('select id, type, template_id')) {
          return {
            rows: parameters[0].includes('MISSING') ? [] : [{ id: parameters[0], type: 'MATERIAL', form_code: 'MAT' }],
            rowCount: parameters[0].includes('MISSING') ? 0 : 1
          };
        }
        return { rows: [], rowCount: 0 };
      },
      release: () => {}
    };
  }

  async connect() { return this.client; }
}

class DeferredConclusionViolationPool {
  constructor() {
    this.commands = [];
    this.stagedReportIds = new Set();
    this.committedReportIds = new Set();
    this.client = {
      query: async (text, parameters = []) => {
        const command = text.trim().split(/\s+/).slice(0, 4).join(' ');
        this.commands.push(command);
        if (command === 'BEGIN') {
          this.stagedReportIds.clear();
          return { rows: [], rowCount: 0 };
        }
        if (text.includes('insert into public.qc_reports')) {
          this.stagedReportIds.add(parameters[0]);
          return { rows: [], rowCount: 1 };
        }
        if (command === 'COMMIT') {
          const error = new Error(
            'Report QC-INVALID-FINAL with status NEEDS_FOLLOW_UP requires an explicit final conclusion'
          );
          error.code = '23514';
          throw error;
        }
        if (command === 'ROLLBACK') {
          this.stagedReportIds.clear();
          return { rows: [], rowCount: 0 };
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
  await assert.rejects(
    repository.create({
      id: 'MAT-ROLLBACK', type: 'MATERIAL', name: 'Rollback',
      checklist_items: [{
        id: 'I-1', parameter_name: 'Value', input_type: 'text', is_required: true,
        required_photo: false
      }]
    }),
    error => error.code === 'INTERNAL_ERROR' && error.cause?.message === 'forced child write failure'
  );
  assert.equal(pool.commands[0], 'BEGIN');
  assert.equal(pool.commands.at(-1), 'ROLLBACK');
  assert.equal(pool.commands.includes('COMMIT'), false);
  assert.equal(pool.released, true);
});

test('report aggregate write rolls back when a batched item write fails', async () => {
  const pool = new FailingPool('insert into public.qc_report_items');
  const repository = new PostgresReportRepository(pool);
  await assert.rejects(
    repository.create({
      id: 'QC-ROLLBACK', type: 'MATERIAL', title: 'Rollback', status: 'DRAFT',
      staff: { name: '', nik: '' }, location: {}, checklist_items: [
        { id: 'I-1', parameter_name: 'Value 1', input_type: 'text' },
        { id: 'I-2', parameter_name: 'Value 2', input_type: 'text' }
      ]
    }),
    error => error.code === 'INTERNAL_ERROR' && error.cause?.message === 'forced child write failure'
  );
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

  for (const table of [
    'qc_report_items',
    'qc_report_samples',
    'qc_report_sample_answers',
    'qc_report_admin_reviews',
    'qc_report_attachments'
  ]) {
    assert.equal(
      pool.commands.some(command => command.startsWith(`insert into public.${table}`)),
      false,
      `${table} must skip empty input`
    );
  }
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

test('deferred final-conclusion violations return 422 and roll back every report row', async () => {
  const pool = new DeferredConclusionViolationPool();
  const repository = new PostgresReportRepository(pool);

  await assert.rejects(
    repository.create({
      id: 'QC-INVALID-FINAL',
      type: 'MATERIAL',
      title: 'Invalid final state',
      status: 'NEEDS_FOLLOW_UP',
      staff: { name: 'Warehouse Staff', nik: 'WH-1' },
      location: {},
      checklist_items: []
    }),
    error => (error.statusCode || error.status) === 422 &&
      error.message ===
        'Kesimpulan akhir wajib diisi sebelum laporan dapat diselesaikan.'
  );

  assert.equal(pool.commands.includes('COMMIT'), true);
  assert.equal(pool.commands.at(-1), 'ROLLBACK');
  assert.equal(pool.stagedReportIds.size, 0);
  assert.equal(pool.committedReportIds.size, 0);
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
  assert.equal(reportPool.commands[0], 'BEGIN');
  assert.equal(reportPool.commands.includes('delete from public.qc_reports where id'), true);
  assert.equal(reportPool.commands.at(-1), 'COMMIT');
});

test('PostgreSQL aggregate deletes roll back and return 404 for missing IDs', async () => {
  const templatePool = new DeletePool();
  const reportPool = new DeletePool();
  await assert.rejects(
    new PostgresTemplateRepository(templatePool).delete('MAT-MISSING'),
    error => (error.statusCode || error.status) === 404
  );
  await assert.rejects(
    new PostgresReportRepository(reportPool).delete('QC-MISSING'),
    error => (error.statusCode || error.status) === 404
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
