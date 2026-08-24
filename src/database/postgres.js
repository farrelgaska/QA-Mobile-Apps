const { Pool } = require('pg');
const { attachDatabasePool } = require('@vercel/functions');
const environment = require('../config/env');
const structuredLogger = require('../utils/logger');

const createPool = (
  config = environment,
  PoolImplementation = Pool,
  logger = structuredLogger
) => {
  const pool = new PoolImplementation({
    connectionString: config.DATABASE_URL,
    max: config.DATABASE_POOL_MAX,
    idleTimeoutMillis: config.DATABASE_IDLE_TIMEOUT_MS,
    connectionTimeoutMillis: config.DATABASE_CONNECTION_TIMEOUT_MS,
    keepAlive: config.DATABASE_KEEP_ALIVE,
    allowExitOnIdle: true,
    ssl: config.DATABASE_SSL
      ? { rejectUnauthorized: config.DATABASE_SSL_REJECT_UNAUTHORIZED }
      : false
  });

  pool.on('error', error => {
    logger.error('database_idle_client_error', {
      code: error?.code,
      error_name: error?.name || 'Error'
    });
  });

  return pool;
};

const createPoolManager = ({
  config = environment,
  poolFactory = () => createPool(config),
  attachPool = attachDatabasePool
} = {}) => {
  let sharedPool;

  const getPool = () => {
    if (config.DATA_PROVIDER !== 'postgres') {
      throw new Error('PostgreSQL pool requested while DATA_PROVIDER is not postgres');
    }
    if (!sharedPool) {
      sharedPool = poolFactory();
      if (config.VERCEL) attachPool(sharedPool);
    }
    return sharedPool;
  };

  const checkDatabaseReachable = async () => {
    if (config.DATA_PROVIDER !== 'postgres') return false;
    try {
      await getPool().query('select 1');
      return true;
    } catch (_) {
      return false;
    }
  };

  return { getPool, checkDatabaseReachable };
};

const poolManager = createPoolManager();

module.exports = {
  createPool,
  createPoolManager,
  getPool: poolManager.getPool,
  checkDatabaseReachable: poolManager.checkDatabaseReachable
};
