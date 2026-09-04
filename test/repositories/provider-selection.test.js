const test = require('node:test');
const assert = require('node:assert/strict');
const { createRepositorySet } = require('../../src/repositories');

test('JSON data provider selects the JSON repository instances', () => {
  const templateRepository = { kind: 'json-template' };
  const reportRepository = { kind: 'json-report' };
  const masterDataRepository = { kind: 'json-master-data' };
  const selected = createRepositorySet('json', {
    jsonMasterDataRepository: masterDataRepository,
    jsonTemplateRepository: templateRepository,
    jsonReportRepository: reportRepository
  });
  assert.equal(selected.dataProvider, 'json');
  assert.equal(selected.masterDataRepository, masterDataRepository);
  assert.equal(selected.templateRepository, templateRepository);
  assert.equal(selected.reportRepository, reportRepository);
});

test('PostgreSQL data provider selects PostgreSQL repositories with one supplied pool', () => {
  const pool = { kind: 'shared-pool' };
  class MasterDataRepository {
    constructor(receivedPool) { this.pool = receivedPool; }
  }
  class TemplateRepository {
    constructor(receivedPool) { this.pool = receivedPool; }
  }
  class ReportRepository {
    constructor(receivedPool) { this.pool = receivedPool; }
  }
  const selected = createRepositorySet('postgres', {
    PostgresMasterDataRepository: MasterDataRepository,
    PostgresTemplateRepository: TemplateRepository,
    PostgresReportRepository: ReportRepository,
    pool
  });
  assert.equal(selected.dataProvider, 'postgres');
  assert.equal(selected.masterDataRepository.pool, pool);
  assert.equal(selected.templateRepository.pool, pool);
  assert.equal(selected.reportRepository.pool, pool);
});
