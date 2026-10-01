const { DATA_PROVIDER } = require('../config/env');

const createRepositorySet = (dataProvider, dependencies = {}) => {
  if (dataProvider === 'postgres') {
    const { PostgresTemplateRepository } = dependencies.PostgresTemplateRepository
      ? dependencies
      : require('./postgres-template.repository');
    const { PostgresReportRepository } = dependencies.PostgresReportRepository
      ? dependencies
      : require('./postgres-report.repository');
    const { PostgresMasterDataRepository } = dependencies.PostgresMasterDataRepository
      ? dependencies
      : require('./postgres-master-data.repository');
    return {
      dataProvider,
      masterDataRepository: new PostgresMasterDataRepository(dependencies.pool),
      templateRepository: new PostgresTemplateRepository(dependencies.pool),
      reportRepository: new PostgresReportRepository(dependencies.pool)
    };
  }

  return {
    dataProvider,
    masterDataRepository: dependencies.jsonMasterDataRepository || require('./json-master-data.repository'),
    templateRepository: dependencies.jsonTemplateRepository || require('./json-template.repository'),
    reportRepository: dependencies.jsonReportRepository || require('./json-report.repository')
  };
};

module.exports = {
  ...createRepositorySet(DATA_PROVIDER),
  createRepositorySet
};
