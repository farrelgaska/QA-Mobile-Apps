const assert = require('assert');
const { describe, it } = require('node:test');
const { assertSafeToMutate } = require('../../scripts/seed/guard');

describe('Canonical Tooling - Production Guard', () => {
  it('refuses to execute if APP_ENV=production', () => {
    assert.throws(
      () => assertSafeToMutate({ APP_ENV: 'production' }),
      /STRICTLY PROHIBITED in the production environment/
    );
  });

  it('refuses to execute if APP_ENV=staging and postgres missing expected host', () => {
    assert.throws(
      () => assertSafeToMutate({
        APP_ENV: 'staging',
        DATA_PROVIDER: 'postgres',
        STAGING_EXPECTED_DB_HOST: ''
      }),
      /STAGING_EXPECTED_DB_HOST is missing/
    );
  });

  it('refuses to execute if APP_ENV=staging and postgres host mismatches URL', () => {
    assert.throws(
      () => assertSafeToMutate({
        APP_ENV: 'staging',
        DATA_PROVIDER: 'postgres',
        STAGING_EXPECTED_DB_HOST: 'expected-host',
        DATABASE_URL: 'postgresql://wrong-host/db'
      }),
      /DATABASE_URL does not match STAGING_EXPECTED_DB_HOST/
    );
  });

  it('allows execution if APP_ENV=staging and postgres matches', () => {
    assert.doesNotThrow(() => assertSafeToMutate({
      APP_ENV: 'staging',
      DATA_PROVIDER: 'postgres',
      STORAGE_PROVIDER: 'none',
      STAGING_EXPECTED_DB_HOST: 'expected-host',
      DATABASE_URL: 'postgresql://expected-host/db'
    }));
  });

  it('refuses to execute if APP_ENV=staging and supabase missing expected ref', () => {
    assert.throws(
      () => assertSafeToMutate({
        APP_ENV: 'staging',
        STORAGE_PROVIDER: 'supabase',
        DATA_PROVIDER: 'json',
        STAGING_EXPECTED_SUPABASE_PROJECT_REF: ''
      }),
      /STAGING_EXPECTED_SUPABASE_PROJECT_REF is missing/
    );
  });

  it('refuses to execute if APP_ENV=staging and supabase ref mismatches URL', () => {
    assert.throws(
      () => assertSafeToMutate({
        APP_ENV: 'staging',
        STORAGE_PROVIDER: 'supabase',
        DATA_PROVIDER: 'json',
        STAGING_EXPECTED_SUPABASE_PROJECT_REF: 'expected-ref',
        SUPABASE_URL: 'https://wrong-ref.supabase.co'
      }),
      /SUPABASE_URL does not match STAGING_EXPECTED_SUPABASE_PROJECT_REF/
    );
  });

  it('allows execution if APP_ENV=staging and supabase matches', () => {
    assert.doesNotThrow(() => assertSafeToMutate({
      APP_ENV: 'staging',
      STORAGE_PROVIDER: 'supabase',
      DATA_PROVIDER: 'json',
      STAGING_EXPECTED_SUPABASE_PROJECT_REF: 'expected-ref',
      SUPABASE_URL: 'https://expected-ref.supabase.co'
    }));
  });
});
