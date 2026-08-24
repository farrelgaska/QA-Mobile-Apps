const env = require('../../src/config/env');

/**
 * Enforces safety boundaries before executing destructive seed/reset commands.
 * Throws an Error and terminates the process if execution is unsafe.
 */
function assertSafeToMutate(testEnvOverride = null) {
  // Allow dependency injection for testing
  const activeEnv = testEnvOverride || process.env;
  const appEnv = testEnvOverride?.APP_ENV || env.APP_ENV;
  const dataProvider = testEnvOverride?.DATA_PROVIDER || env.DATA_PROVIDER;
  const storageProvider = testEnvOverride?.STORAGE_PROVIDER || env.STORAGE_PROVIDER;
  const databaseUrl = testEnvOverride?.DATABASE_URL || env.DATABASE_URL;
  const supabaseUrl = testEnvOverride?.SUPABASE_URL || env.SUPABASE_URL;

  if (appEnv === 'production') {
    throw new Error(
      '[SAFETY GUARD] REFUSED: Destructive operations (seed/reset/reseed) are STRICTLY PROHIBITED in the production environment.'
    );
  }

  if (appEnv === 'staging') {
    if (dataProvider === 'postgres') {
      const expectedDbHost = activeEnv.STAGING_EXPECTED_DB_HOST?.trim() || null;
      if (!expectedDbHost) {
        throw new Error(
          '[SAFETY GUARD] REFUSED: STAGING_EXPECTED_DB_HOST is missing. Cannot verify remote database identity.'
        );
      }
      if (!databaseUrl || !databaseUrl.includes(expectedDbHost)) {
        throw new Error(
          `[SAFETY GUARD] REFUSED: DATABASE_URL does not match STAGING_EXPECTED_DB_HOST "${expectedDbHost}".`
        );
      }
    }

    if (storageProvider === 'supabase') {
      const expectedSupabaseRef = activeEnv.STAGING_EXPECTED_SUPABASE_PROJECT_REF?.trim() || null;
      if (!expectedSupabaseRef) {
        throw new Error(
          '[SAFETY GUARD] REFUSED: STAGING_EXPECTED_SUPABASE_PROJECT_REF is missing. Cannot verify remote storage identity.'
        );
      }
      if (!supabaseUrl || !supabaseUrl.includes(expectedSupabaseRef)) {
        throw new Error(
          `[SAFETY GUARD] REFUSED: SUPABASE_URL does not match STAGING_EXPECTED_SUPABASE_PROJECT_REF "${expectedSupabaseRef}".`
        );
      }
    }
  }

  // Local/development environment is inherently safe
}

module.exports = { assertSafeToMutate };
