const { Pool } = require('pg');
const { attachDatabasePool } = require('@vercel/functions');
const environment = require('../config/env');

const createPool = (config = environment, PoolImplementation = Pool) => new PoolImplementation({
  connectionString: config.DATABASE_URL,
  max: config.DATABASE_POOL_MAX,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5000,
  allowExitOnIdle: true,
  ssl: config.DATABASE_SSL
    ? { rejectUnauthorized: config.DATABASE_SSL_REJECT_UNAUTHORIZED }
    : false
});

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
