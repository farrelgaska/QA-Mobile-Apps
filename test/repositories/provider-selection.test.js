const test = require('node:test');
const assert = require('node:assert/strict');
const { createRepositorySet } = require('../../src/repositories');

test('JSON data provider selects the JSON repository instances', () => {
  const templateRepository = { kind: 'json-template' };
  const reportRepository = { kind: 'json-report' };
  const selected = createRepositorySet('json', {
    jsonTemplateRepository: templateRepository,
    jsonReportRepository: reportRepository
  });
  assert.equal(selected.dataProvider, 'json');
  assert.equal(selected.templateRepository, templateRepository);
  assert.equal(selected.reportRepository, reportRepository);
});

test('PostgreSQL data provider selects PostgreSQL repositories with one supplied pool', () => {
  const pool = { kind: 'shared-pool' };
  class TemplateRepository {
    constructor(receivedPool) { this.pool = receivedPool; }
  }
  class ReportRepository {
    constructor(receivedPool) { this.pool = receivedPool; }
  }
  const selected = createRepositorySet('postgres', {
    PostgresTemplateRepository: TemplateRepository,
    PostgresReportRepository: ReportRepository,
    pool
  });
  assert.equal(selected.dataProvider, 'postgres');
  assert.equal(selected.templateRepository.pool, pool);
  assert.equal(selected.reportRepository.pool, pool);
});
