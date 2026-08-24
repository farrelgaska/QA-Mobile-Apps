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
  // ─── APP_ENV ──────────────────────────────────────────────────────────────
  // Valid values: development | staging | production
  // - Non-Vercel (local): defaults to "development" when omitted.
  // - Vercel deployment (VERCEL=1): APP_ENV MUST be set explicitly; omitting or
  //   using an invalid value is a startup failure to prevent silent misconfiguration.
  const VALID_APP_ENVS = ['development', 'staging', 'production'];
  const isVercel = environment.VERCEL === '1' || environment.VERCEL === 'true';
  const rawAppEnv = environment.APP_ENV?.trim().toLowerCase();

  let appEnv;
  if (!rawAppEnv) {
    if (isVercel) {
      throw new Error(
        'APP_ENV is required on Vercel deployments. Set it to "development", "staging", or "production".'
      );
    }
    appEnv = 'development';
  } else if (!VALID_APP_ENVS.includes(rawAppEnv)) {
    throw new Error(
      `APP_ENV "${rawAppEnv}" is not valid. Must be one of: ${VALID_APP_ENVS.join(', ')}.`
    );
  } else {
    appEnv = rawAppEnv;
  }

  // ─── Data & Storage providers ────────────────────────────────────────────
  const dataProvider = (environment.DATA_PROVIDER || 'json').trim().toLowerCase();
  if (!['json', 'postgres'].includes(dataProvider)) {
    throw new Error('DATA_PROVIDER must be either "json" or "postgres"');
  }

  const storageProvider = environment.STORAGE_PROVIDER?.trim().toLowerCase() || null;
  if (storageProvider && !['local', 'supabase', 's3', 'gcs'].includes(storageProvider)) {
    throw new Error('STORAGE_PROVIDER must be one of "local", "supabase", "s3", or "gcs"');
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

  // ─── Staging resource guard ───────────────────────────────────────────────
  // When APP_ENV=staging, validate that active remote resources are not
  // production resources. Use explicit expected identifiers supplied via
  // deployment environment variables — no identifiers are hardcoded in source.
  //
  //   STAGING_EXPECTED_DB_HOST           — fragment that must appear in DATABASE_URL host
  //   STAGING_EXPECTED_SUPABASE_PROJECT_REF — fragment that must appear in SUPABASE_URL
  //
  // If an expected identifier is set and the actual URL does not contain it,
  // startup fails. If an expected identifier is not set, a warning is logged
  // (guard cannot validate without an identifier).
  if (appEnv === 'staging') {
    const expectedDbHost = environment.STAGING_EXPECTED_DB_HOST?.trim() || null;
    const expectedSupabaseRef = environment.STAGING_EXPECTED_SUPABASE_PROJECT_REF?.trim() || null;

    if (dataProvider === 'postgres') {
      if (!expectedDbHost) {
        throw new Error(
          '[STAGING GUARD] STAGING_EXPECTED_DB_HOST is required when APP_ENV=staging and DATA_PROVIDER=postgres. ' +
          'Set it to a unique hostname fragment of the staging DATABASE_URL to prevent accidental use of the wrong database.'
        );
      }
      if (!databaseUrl || !databaseUrl.includes(expectedDbHost)) {
        throw new Error(
          `[STAGING GUARD] DATABASE_URL does not match STAGING_EXPECTED_DB_HOST "${expectedDbHost}". ` +
          'Refusing to start: this staging deployment may be pointed at the wrong database.'
        );
      }
    }

    if (storageProvider === 'supabase') {
      if (!expectedSupabaseRef) {
        throw new Error(
          '[STAGING GUARD] STAGING_EXPECTED_SUPABASE_PROJECT_REF is required when APP_ENV=staging and STORAGE_PROVIDER=supabase. ' +
          'Set it to the staging Supabase project ref to prevent accidental use of the wrong Supabase project.'
        );
      }
      if (!supabaseUrl || !supabaseUrl.includes(expectedSupabaseRef)) {
        throw new Error(
          `[STAGING GUARD] SUPABASE_URL does not match STAGING_EXPECTED_SUPABASE_PROJECT_REF "${expectedSupabaseRef}". ` +
          'Refusing to start: this staging deployment may be pointed at the wrong Supabase project.'
        );
      }
    }
  }

  // ─── CORS ─────────────────────────────────────────────────────────────────
  // Explicit CORS_ORIGINS is always authoritative.
  // Implicit localhost allowance is added only in development (not staging/production).
  const corsOrigins = environment.CORS_ORIGINS
    ? environment.CORS_ORIGINS.split(',').map(origin => origin.trim()).filter(Boolean)
    : (appEnv === 'development' ? ['http://localhost:5173', 'http://localhost:3000'] : []);

  return {
    APP_ENV: appEnv,
    PORT: parseInteger('PORT', environment.PORT, 3002, { max: 65535 }),
    CORS_ORIGINS: corsOrigins,
    // Whether localhost:* is implicitly allowed (development only)
    CORS_ALLOW_LOCALHOST: appEnv === 'development',
    DATA_PROVIDER: dataProvider,
    STORAGE_PROVIDER: storageProvider,
    SUPABASE_URL: supabaseUrl,
    SUPABASE_SERVICE_ROLE_KEY: supabaseServiceRoleKey,
    DATABASE_URL: databaseUrl,
    DATABASE_POOL_MAX: parseInteger('DATABASE_POOL_MAX', environment.DATABASE_POOL_MAX, 2, { max: 20 }),
    DATABASE_CONNECTION_TIMEOUT_MS: parseInteger(
      'DATABASE_CONNECTION_TIMEOUT_MS',
      environment.DATABASE_CONNECTION_TIMEOUT_MS,
      10000,
      { max: 60000 }
    ),
    DATABASE_IDLE_TIMEOUT_MS: parseInteger(
      'DATABASE_IDLE_TIMEOUT_MS',
      environment.DATABASE_IDLE_TIMEOUT_MS,
      30000,
      { max: 300000 }
    ),
    DATABASE_KEEP_ALIVE: parseBoolean(
      'DATABASE_KEEP_ALIVE',
      environment.DATABASE_KEEP_ALIVE,
      true
    ),
    VERCEL: isVercel,
    DATABASE_SSL: parseBoolean('DATABASE_SSL', environment.DATABASE_SSL, true),
    DATABASE_SSL_REJECT_UNAUTHORIZED: parseBoolean(
      'DATABASE_SSL_REJECT_UNAUTHORIZED',
      environment.DATABASE_SSL_REJECT_UNAUTHORIZED,
      true
    ),
    ADMIN_DEMO_TOKEN: environment.ADMIN_DEMO_TOKEN?.trim() || null,
    SENTRY_DSN: environment.SENTRY_DSN?.trim() || null,
    SENTRY_TRACES_SAMPLE_RATE: environment.SENTRY_TRACES_SAMPLE_RATE?.trim() || '0'
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
