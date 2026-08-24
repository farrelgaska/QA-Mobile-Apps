const express = require('express');
const { dataProvider } = require('../repositories');
const { checkDatabaseReachable } = require('../database/postgres');
const environment = require('../config/env');

const createHealthRouter = ({
  provider = dataProvider,
  checkDatabase = checkDatabaseReachable,
  config = environment
} = {}) => {
  const router = express.Router();

  router.get('/', async (req, res) => {
    const databaseReachable = await checkDatabase();
    const storageProvider = config.STORAGE_PROVIDER ||
      (provider === 'json' ? 'local' : 'unconfigured');
    const storageConfigured = storageProvider === 'local'
      ? config.APP_ENV !== 'production'
      : storageProvider === 'supabase' &&
        Boolean(config.SUPABASE_URL && config.SUPABASE_SERVICE_ROLE_KEY);
    const ready = (provider !== 'postgres' || databaseReachable) && storageConfigured;

    res.json({
      status: ready ? 'OK' : 'DEGRADED',
      timestamp: new Date().toISOString(),
      alive: true,
      ready,
      environment: config.APP_ENV,
      data_provider: provider,
      database_reachable: databaseReachable,
      storage_provider: storageProvider,
      storage_configured: storageConfigured
    });
  });

  return router;
};

module.exports = createHealthRouter();
module.exports.createHealthRouter = createHealthRouter;
