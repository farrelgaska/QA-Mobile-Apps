'use strict';

/**
 * test/config/env.test.js
 *
 * Tests for APP_ENV parsing, Vercel fail-fast, staging resource guard,
 * and per-environment CORS behaviour in src/config/env.js::parseEnvironment.
 *
 * Run standalone: node --test test/config/env.test.js
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

// Import only the pure parser — does not execute process.env at import time.
const { parseEnvironment } = require('../../src/config/env');

// ─── Minimal valid base env (development, JSON data provider) ─────────────────
const BASE = {
  DATA_PROVIDER: 'json',
  PORT: '3002'
};

describe('STORAGE_PROVIDER', () => {
  it('accepts the documented local provider', () => {
    assert.equal(
      parseEnvironment({ ...BASE, STORAGE_PROVIDER: 'local' }).STORAGE_PROVIDER,
      'local'
    );
  });
});

// ─── APP_ENV ─────────────────────────────────────────────────────────────────

describe('APP_ENV', () => {
  it('defaults to "development" on non-Vercel when omitted', () => {
    const env = parseEnvironment({ ...BASE });
    assert.equal(env.APP_ENV, 'development');
  });

  it('accepts "development" explicitly', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'development' });
    assert.equal(env.APP_ENV, 'development');
  });

  it('accepts "staging" explicitly', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'staging' });
    assert.equal(env.APP_ENV, 'staging');
  });

  it('accepts "production" explicitly', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'production' });
    assert.equal(env.APP_ENV, 'production');
  });

  it('rejects an invalid APP_ENV value', () => {
    assert.throws(
      () => parseEnvironment({ ...BASE, APP_ENV: 'preview' }),
      /APP_ENV "preview" is not valid/
    );
  });

  it('rejects empty-string APP_ENV as if absent on non-Vercel (defaults to development)', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: '' });
    assert.equal(env.APP_ENV, 'development');
  });
});

// ─── Vercel fail-fast ─────────────────────────────────────────────────────────

describe('APP_ENV on Vercel', () => {
  it('throws when APP_ENV is missing on VERCEL=1', () => {
    assert.throws(
      () => parseEnvironment({ ...BASE, VERCEL: '1' }),
      /APP_ENV is required on Vercel deployments/
    );
  });

  it('throws when APP_ENV is invalid on VERCEL=1', () => {
    assert.throws(
      () => parseEnvironment({ ...BASE, VERCEL: '1', APP_ENV: 'canary' }),
      /APP_ENV "canary" is not valid/
    );
  });

  it('accepts a valid APP_ENV on VERCEL=1', () => {
    const env = parseEnvironment({ ...BASE, VERCEL: '1', APP_ENV: 'production' });
    assert.equal(env.APP_ENV, 'production');
    assert.equal(env.VERCEL, true);
  });

  it('accepts staging APP_ENV on VERCEL=1', () => {
    const env = parseEnvironment({ ...BASE, VERCEL: '1', APP_ENV: 'staging' });
    assert.equal(env.APP_ENV, 'staging');
  });
});

// ─── Staging resource guard ───────────────────────────────────────────────────

const STAGING_BASE = {
  ...BASE,
  APP_ENV: 'staging',
  DATA_PROVIDER: 'postgres',
  DATABASE_URL: 'postgresql://postgres.staging-abc123:pw@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres',
  STORAGE_PROVIDER: 'supabase',
  SUPABASE_URL: 'https://staging-abc123.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'staging-service-role-key'
};

describe('staging resource guard — DATABASE_URL', () => {
  it('throws when STAGING_EXPECTED_DB_HOST is missing (fail-fast)', () => {
    assert.throws(
      () => parseEnvironment({
        ...STAGING_BASE,
        STAGING_EXPECTED_SUPABASE_PROJECT_REF: 'staging-abc123'
        // STAGING_EXPECTED_DB_HOST intentionally absent
      }),
      /STAGING GUARD.*STAGING_EXPECTED_DB_HOST is required/
    );
  });

  it('throws when STAGING_EXPECTED_DB_HOST does not match DATABASE_URL', () => {
    assert.throws(
      () => parseEnvironment({
        ...STAGING_BASE,
        STAGING_EXPECTED_DB_HOST: 'wrong-host-fragment',
        STAGING_EXPECTED_SUPABASE_PROJECT_REF: 'staging-abc123'
      }),
      /STAGING GUARD.*DATABASE_URL does not match STAGING_EXPECTED_DB_HOST/
    );
  });

  it('passes when STAGING_EXPECTED_DB_HOST matches DATABASE_URL', () => {
    const env = parseEnvironment({
      ...STAGING_BASE,
      STAGING_EXPECTED_DB_HOST: 'staging-abc123',
      STAGING_EXPECTED_SUPABASE_PROJECT_REF: 'staging-abc123'
    });
    assert.equal(env.APP_ENV, 'staging');
  });

  it('does not require STAGING_EXPECTED_DB_HOST when DATA_PROVIDER=json (inactive provider)', () => {
    // json provider has no remote DB — guard must not apply
    const env = parseEnvironment({
      ...BASE,
      APP_ENV: 'staging'
      // no STAGING_EXPECTED_DB_HOST, no STAGING_EXPECTED_SUPABASE_PROJECT_REF
    });
    assert.equal(env.APP_ENV, 'staging');
  });
});

describe('staging resource guard — SUPABASE_URL', () => {
  it('throws when STAGING_EXPECTED_SUPABASE_PROJECT_REF is missing (fail-fast)', () => {
    assert.throws(
      () => parseEnvironment({
        ...STAGING_BASE,
        STAGING_EXPECTED_DB_HOST: 'staging-abc123'
        // STAGING_EXPECTED_SUPABASE_PROJECT_REF intentionally absent
      }),
      /STAGING GUARD.*STAGING_EXPECTED_SUPABASE_PROJECT_REF is required/
    );
  });

  it('throws when STAGING_EXPECTED_SUPABASE_PROJECT_REF does not match SUPABASE_URL', () => {
    assert.throws(
      () => parseEnvironment({
        ...STAGING_BASE,
        STAGING_EXPECTED_DB_HOST: 'staging-abc123',
        STAGING_EXPECTED_SUPABASE_PROJECT_REF: 'wrong-project-ref'
      }),
      /STAGING GUARD.*SUPABASE_URL does not match STAGING_EXPECTED_SUPABASE_PROJECT_REF/
    );
  });

  it('passes when STAGING_EXPECTED_SUPABASE_PROJECT_REF matches SUPABASE_URL', () => {
    const env = parseEnvironment({
      ...STAGING_BASE,
      STAGING_EXPECTED_DB_HOST: 'staging-abc123',
      STAGING_EXPECTED_SUPABASE_PROJECT_REF: 'staging-abc123'
    });
    assert.equal(env.APP_ENV, 'staging');
  });

  it('does not require STAGING_EXPECTED_SUPABASE_PROJECT_REF when STORAGE_PROVIDER is not supabase (inactive provider)', () => {
    // No supabase storage configured — guard must not apply
    const env = parseEnvironment({
      ...BASE,
      APP_ENV: 'staging',
      DATA_PROVIDER: 'postgres',
      DATABASE_URL: 'postgresql://postgres.staging-abc123:pw@aws-0-ap.pooler.supabase.com:6543/postgres',
      STAGING_EXPECTED_DB_HOST: 'staging-abc123'
      // no STORAGE_PROVIDER, no STAGING_EXPECTED_SUPABASE_PROJECT_REF
    });
    assert.equal(env.APP_ENV, 'staging');
  });
});

// ─── CORS ─────────────────────────────────────────────────────────────────────

describe('CORS_ALLOW_LOCALHOST', () => {
  it('is true in development', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'development' });
    assert.equal(env.CORS_ALLOW_LOCALHOST, true);
  });

  it('is false in staging', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'staging' });
    assert.equal(env.CORS_ALLOW_LOCALHOST, false);
  });

  it('is false in production', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'production' });
    assert.equal(env.CORS_ALLOW_LOCALHOST, false);
  });
});

describe('CORS_ORIGINS default', () => {
  it('development without explicit CORS_ORIGINS defaults to localhost list', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'development' });
    assert.deepEqual(env.CORS_ORIGINS, ['http://localhost:5173', 'http://localhost:3000']);
  });

  it('staging without explicit CORS_ORIGINS defaults to empty list', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'staging' });
    assert.deepEqual(env.CORS_ORIGINS, []);
  });

  it('production without explicit CORS_ORIGINS defaults to empty list', () => {
    const env = parseEnvironment({ ...BASE, APP_ENV: 'production' });
    assert.deepEqual(env.CORS_ORIGINS, []);
  });

  it('explicit CORS_ORIGINS overrides default in all environments', () => {
    const env = parseEnvironment({
      ...BASE,
      APP_ENV: 'staging',
      CORS_ORIGINS: 'https://staging.example.com,https://staging2.example.com'
    });
    assert.deepEqual(env.CORS_ORIGINS, ['https://staging.example.com', 'https://staging2.example.com']);
  });
});
