const { DATA_PROVIDER } = require('../config/env');

const createRepositorySet = (dataProvider, dependencies = {}) => {
  if (dataProvider === 'postgres') {
    const { PostgresTemplateRepository } = dependencies.PostgresTemplateRepository
      ? dependencies
      : require('./postgres-template.repository');
    const { PostgresReportRepository } = dependencies.PostgresReportRepository
      ? dependencies
      : require('./postgres-report.repository');
    return {
      dataProvider,
      templateRepository: new PostgresTemplateRepository(dependencies.pool),
      reportRepository: new PostgresReportRepository(dependencies.pool)
    };
  }

  return {
    dataProvider,
    templateRepository: dependencies.jsonTemplateRepository || require('./json-template.repository'),
    reportRepository: dependencies.jsonReportRepository || require('./json-report.repository')
  };
};

module.exports = {
  ...createRepositorySet(DATA_PROVIDER),
  createRepositorySet
};
