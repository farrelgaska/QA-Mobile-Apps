# Backend data and object-storage providers

Mobile and web clients always use the Express API. They do not connect to
Supabase directly. The backend selects one data repository implementation at
startup with `DATA_PROVIDER`.

`STORAGE_PROVIDER` independently selects QC evidence object storage. `local`
and `supabase` are implemented. `s3` and `gcs` remain reserved values and fail
storage initialization because no adapter exists. See
`../../docs/STORAGE_INTEGRITY.md` from the workspace root for the audited evidence
lifecycle and known limitations.

## Local JSON mode

```env
DATA_PROVIDER=json
STORAGE_PROVIDER=local
```

This is the default. Templates and reports continue to use
`data/templates.json` and `data/reports.json`. It requires no database and is
appropriate for local development and offline fallback. Writes retain the
existing atomic temporary-file replacement behavior.

Evidence files are written below `.local-storage/qc-evidence` and served from
`/mock-storage` only outside production. Missing objects are returned through
the signed-URL endpoint's `failed_paths` field.

## Supabase Storage mode

```env
STORAGE_PROVIDER=supabase
SUPABASE_URL=https://PROJECT_REF.supabase.co
SUPABASE_SERVICE_ROLE_KEY=replace-with-service-role-key
```

The backend alone uses the service-role credential. It stores evidence in the
private `qc-evidence` bucket and returns one-hour signed display URLs; reports
persist object paths, never those URLs.

## Supabase Postgres mode

```env
DATA_PROVIDER=postgres
DATABASE_URL=postgresql://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres
DATABASE_POOL_MAX=2
DATABASE_SSL=true
DATABASE_SSL_REJECT_UNAUTHORIZED=true
```

`DATABASE_URL` is required only in Postgres mode and is read exclusively from
the environment. It is never returned by the API or written to logs. The pool
defaults to two connections for Vercel-compatible deployment and can be tuned with
`DATABASE_POOL_MAX` (maximum accepted value: 20).

The URL example uses Supabase's transaction pooler on port `6543`. On Vercel,
the singleton `pg` pool is registered once with `attachDatabasePool` from
`@vercel/functions`. Local processes retain ordinary `pg.Pool` behavior. A new
pool is never created per request.

Template and report aggregate writes run inside transactions. Relational rows
are reconstructed into the canonical nested contracts before being returned by
the unchanged Express routes. Existing public string IDs are preserved.

The deployed schema has RLS enabled with no public policies. PostgreSQL access
therefore remains server-side through the Express backend credentials. Do not
place the database URL in mobile or web configuration.

## Health response

`GET /health` includes `data_provider` and a boolean
`database_reachable`. JSON mode reports `false` because no PostgreSQL database
is configured or contacted. A failed Postgres probe is reported as `false`
without exposing connection details.

## Verification

```sh
npm run check
npm test
```

Repository tests use mock PostgreSQL pools and OS-temporary JSON files. They do
not connect to Supabase.
