# Backend Staging Environment

## Environment model

The backend uses `APP_ENV` (set via environment variable) to distinguish:

| `APP_ENV` | Usage |
|-----------|-------|
| `development` | Local developer machine. Defaults when `VERCEL` is not set and `APP_ENV` is omitted. |
| `staging` | Pre-production integration environment. Must be explicitly set. |
| `production` | Live production. Must be explicitly set on the production Vercel deployment. |

**Vercel deployments (`VERCEL=1`):** `APP_ENV` is required. Missing or invalid value
causes immediate startup failure. This prevents a misconfigured deployment from
silently running as development.

---

## CORS

| Environment | Localhost allowed | `*.vercel.app` wildcard | Explicit `CORS_ORIGINS` |
|-------------|------------------|------------------------|------------------------|
| `development` | ✅ (implicit) | ❌ removed | Optional |
| `staging` | ❌ | ❌ removed | **Required** |
| `production` | ❌ | ❌ removed | **Required** |

Set `CORS_ORIGINS` as a comma-separated list of allowed frontend origins:

```
CORS_ORIGINS=https://staging-web.vercel.app
```

---

## Staging resource guard

When `APP_ENV=staging`, the backend validates that active remote resources
belong to the staging environment, not production.

### How to configure

Set these env vars in the staging Vercel deployment:

| Variable | Purpose |
|----------|---------|
| `STAGING_EXPECTED_DB_HOST` | A unique hostname fragment that must appear in `DATABASE_URL`. Example: the staging Supabase project ref. |
| `STAGING_EXPECTED_SUPABASE_PROJECT_REF` | A unique project ref fragment that must appear in `SUPABASE_URL`. |

If an expected identifier is set and the actual URL does not contain it,
the backend **refuses to start**:

```
[STAGING GUARD] DATABASE_URL does not match STAGING_EXPECTED_DB_HOST "staging-abc123".
Refusing to start: this staging deployment may be pointed at the wrong database.
```

If an expected identifier is **not** set, the guard logs a warning but does not
block startup (it cannot validate without an identifier). This is the state before
staging infrastructure is created.

### No production identifiers in source

The guard does not hardcode any production Supabase project refs or database hosts.
All validation is driven by the deployment environment variables, which you control.

---

## Required external infrastructure (not automated)

The following must be created manually before staging is operational:

- [ ] Create a staging Supabase project (separate from production)
- [ ] Run all migrations from `supabase/migrations/` against the staging project
- [ ] Create the `qc-evidence` storage bucket in the staging Supabase project
- [ ] Create a staging Vercel deployment for `mock-api`
  - Set env vars from `.env.staging.example` (replace placeholders with real values)
  - Set `APP_ENV=staging`
  - Set `CORS_ORIGINS` to the staging web admin URL
  - Set `STAGING_EXPECTED_DB_HOST` and `STAGING_EXPECTED_SUPABASE_PROJECT_REF`
- [ ] Create a staging Vercel deployment for `apps/web`
  - Set env vars from `apps/web/.env.staging.example`
  - Set `VITE_API_BASE_URL` to the staging backend URL

---

## Environment variable reference

See `.env.staging.example` for the full list of variables required for a staging deployment.
See `.env.example` for local development variables.
