const path = require('path');
const dotenv = require('dotenv');

// Load environment variables from .env
dotenv.config({ path: path.join(__dirname, '../../.env') });

const parseInteger = (name, rawValue, defaultValue, { min = 1, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const value = rawValue === undefined || rawValue === '' ? defaultValue : Number(rawValue);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(`${name} must be an integer between ${min} and ${max}`);
  }
  return value;
};

const parseBoolean = (name, rawValue, defaultValue) => {
  if (rawValue === undefined || rawValue === '') return defaultValue;
  if (rawValue === 'true') return true;
  if (rawValue === 'false') return false;
  throw new Error(`${name} must be either "true" or "false"`);
};

const parseEnvironment = (environment) => {
  const dataProvider = (environment.DATA_PROVIDER || 'json').trim().toLowerCase();
  if (!['json', 'postgres'].includes(dataProvider)) {
    throw new Error('DATA_PROVIDER must be either "json" or "postgres"');
  }

  const storageProvider = environment.STORAGE_PROVIDER?.trim().toLowerCase() || null;
  if (storageProvider && !['supabase', 's3', 'gcs'].includes(storageProvider)) {
    throw new Error('STORAGE_PROVIDER must be one of "supabase", "s3", or "gcs"');
  }

  const databaseUrl = environment.DATABASE_URL?.trim() || null;
  if (dataProvider === 'postgres' && !databaseUrl) {
    throw new Error('DATABASE_URL is required when DATA_PROVIDER=postgres');
  }

  const supabaseUrl = environment.SUPABASE_URL?.trim() || null;
  const supabaseServiceRoleKey = environment.SUPABASE_SERVICE_ROLE_KEY?.trim() || null;
  if (storageProvider === 'supabase' && (!supabaseUrl || !supabaseServiceRoleKey)) {
    throw new Error(
      'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required when STORAGE_PROVIDER=supabase'
    );
  }

  return {
    PORT: parseInteger('PORT', environment.PORT, 3002, { max: 65535 }),
    CORS_ORIGINS: environment.CORS_ORIGINS
      ? environment.CORS_ORIGINS.split(',').map(origin => origin.trim()).filter(Boolean)
      : ['http://localhost:5173', 'http://localhost:3000'],
    DATA_PROVIDER: dataProvider,
    STORAGE_PROVIDER: storageProvider,
    SUPABASE_URL: supabaseUrl,
    SUPABASE_SERVICE_ROLE_KEY: supabaseServiceRoleKey,
    DATABASE_URL: databaseUrl,
    DATABASE_POOL_MAX: parseInteger('DATABASE_POOL_MAX', environment.DATABASE_POOL_MAX, 2, { max: 20 }),
    VERCEL: environment.VERCEL === '1' || environment.VERCEL === 'true',
    DATABASE_SSL: parseBoolean('DATABASE_SSL', environment.DATABASE_SSL, true),
    DATABASE_SSL_REJECT_UNAUTHORIZED: parseBoolean(
      'DATABASE_SSL_REJECT_UNAUTHORIZED',
      environment.DATABASE_SSL_REJECT_UNAUTHORIZED,
      true
    )
  };
};

const environment = parseEnvironment(process.env);

const REPORTS_FILE = path.join(__dirname, '../../data/reports.json');
const TEMPLATES_FILE = path.join(__dirname, '../../data/templates.json');

module.exports = {
  ...environment,
  REPORTS_FILE,
  TEMPLATES_FILE,
  parseEnvironment
};
