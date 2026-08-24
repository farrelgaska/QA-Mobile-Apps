# QA Digitalization Backup and Restore Runbook

## Scope

This runbook covers the application-owned PostgreSQL or JSON state and QC evidence objects. It does not create schedules, cloud backup infrastructure, or production credentials. Run every restore against an isolated local/staging target first, with application writers stopped.

Never place a database dump, JSON backup, evidence archive, `.env`, password, token, DSN, or real production record in this repository. Store backups in an access-controlled location outside `D:\QA-APPS-MOBILE`.

## Data inventory

### PostgreSQL

The migrations in `mock-api/supabase/migrations` define these application tables:

| Parent state | Dependent state | Relationship |
| --- | --- | --- |
| `qc_templates` | `qc_template_items` | Cascades on template delete |
| `qc_templates` | `qc_reports.template_id` | Report reference becomes null on template delete |
| `qc_reports` | `qc_report_items` | Cascades on report delete |
| `qc_reports` | `qc_report_admin_reviews` | Cascades on report delete |
| `qc_reports` | `qc_report_samples` | Cascades on report delete |
| `qc_report_samples` | `qc_report_sample_answers` | Composite FK; cascades on sample delete |
| `qc_reports` / `qc_report_items` | `qc_report_attachments` | General or item evidence metadata; cascades on parent delete |
| `qc_reports` | `api_idempotency_keys` | Deferred FK; cascades on report delete |

`qc_reports.template_snapshot` is embedded JSONB historical state and must be preserved with the report. Database evidence fields contain canonical object paths/metadata, not image bytes.

### JSON provider

The authoritative runtime directory is `mock-api/data`:

- `templates.json`: templates and nested checklist items.
- `reports.json`: reports, historical template snapshots, report children, samples, answers, reviews, and evidence paths.
- `idempotency.json`: create-report request hashes and report references. The repository treats an absent file as an empty object; the backup tool materializes it as `{}` so every backup contains the complete three-file state.

`mock-api/scripts/seed/baseline.json` and `mock-api/test/fixtures/**` are seed/test inputs, not runtime backups. `npm run db:reset` and `npm run db:reseed` erase report and idempotency state and must not be used as recovery commands.

### Evidence storage

- Local: `mock-api/.local-storage/qc-evidence`, retaining paths such as `reports/<report_id>/general/<uuid>.jpg`.
- Remote production: private Supabase Storage bucket `qc-evidence`.

Database/JSON backups preserve only evidence references. A recoverable report with photos requires a separate binary-object backup containing the same canonical relative paths.

### Configuration prerequisites

Recover configuration names and values from the approved secret/configuration manager, never from a data backup:

- `APP_ENV`, `DATA_PROVIDER`, `DATABASE_URL`
- `DATABASE_SSL`, `DATABASE_SSL_REJECT_UNAUTHORIZED`, and database pool/timeout variables
- `STORAGE_PROVIDER`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
- `STAGING_EXPECTED_DB_HOST`, `STAGING_EXPECTED_SUPABASE_PROJECT_REF` for staging guards
- `PORT`, `CORS_ORIGINS`, and `ADMIN_DEMO_TOKEN` as required by the deployment

Do not copy source credentials to the restore target. Provision target-specific credentials.

## Consistency boundary

`pg_dump` takes a transactionally consistent PostgreSQL snapshot. A PostgreSQL dump does not atomically include Supabase Storage object bytes, so pause report/evidence writes while capturing both when cross-service consistency is required.

The JSON provider updates individual files atomically, but the three files are not one atomic transaction. Stop the Backend and all writers before JSON backup or restore. The backup command reads the files twice and rejects detected changes, but that check is not a substitute for stopping writers.

Local evidence files also have no transaction spanning JSON/DB metadata. Pause uploads while copying them and label data and object backups with the same recovery-point timestamp.

## PostgreSQL backup

Prerequisites:

- PostgreSQL client tools compatible with the server (`pg_dump`, `pg_restore`, `psql`).
- Read access to the source and write access only to the external backup location.
- A securely injected `DATABASE_URL`, preferably through `PGSERVICE`/`.pgpass` or the approved secret manager. Never paste credentials into source files or commit them.
- The source Git revision and migration-file hashes recorded beside the dump.

First identify the source and record counts without printing its connection string:

```powershell
psql $env:DATABASE_URL -X -v ON_ERROR_STOP=1 -c "select current_database(), inet_server_addr(), current_user;"
psql $env:DATABASE_URL -X -v ON_ERROR_STOP=1 -c "select 'qc_templates' as table_name, count(*) from public.qc_templates union all select 'qc_template_items', count(*) from public.qc_template_items union all select 'qc_reports', count(*) from public.qc_reports union all select 'qc_report_items', count(*) from public.qc_report_items union all select 'qc_report_admin_reviews', count(*) from public.qc_report_admin_reviews union all select 'qc_report_attachments', count(*) from public.qc_report_attachments union all select 'qc_report_samples', count(*) from public.qc_report_samples union all select 'qc_report_sample_answers', count(*) from public.qc_report_sample_answers union all select 'api_idempotency_keys', count(*) from public.api_idempotency_keys order by table_name;"
```

Create a custom-format dump of the application schema. The destination must be outside the repository and must not already exist:

```powershell
$dumpFile = 'E:\qa-backups\qa-public-20260824T120000+0700.dump'
if (Test-Path -LiteralPath $dumpFile) { throw "Refusing to overwrite $dumpFile" }
pg_dump --dbname $env:DATABASE_URL --format custom --schema public --no-owner --no-privileges --file $dumpFile
pg_restore --list $dumpFile
Get-FileHash -Algorithm SHA256 -LiteralPath $dumpFile
```

The custom dump contains the `public` schema, application data, constraints, indexes, sequences, functions, and relationships. Save the source identity, row counts, SHA-256, Git revision, and hashes/names of `mock-api/supabase/migrations/*.sql` beside the dump. Do not add those operational artifacts to Git.

## PostgreSQL restore

1. Provision or identify an empty, isolated local/staging database. Use a target-specific `RESTORE_DATABASE_URL`.
2. Verify the target identity and compare its host/project/database with the production identity out of band:

   ```powershell
   psql $env:RESTORE_DATABASE_URL -X -v ON_ERROR_STOP=1 -c "select current_database(), inet_server_addr(), current_user;"
   ```

3. Stop application writers. Restore the custom dump as one transaction:

   ```powershell
   pg_restore --dbname $env:RESTORE_DATABASE_URL --exit-on-error --single-transaction --no-owner --no-privileges 'E:\qa-backups\qa-public-20260824T120000+0700.dump'
   ```

4. A schema-and-data dump already contains the schema at its backup revision; do not apply the same migrations first. Deploy the matching application revision. Apply only reviewed migrations newer than the recorded backup revision.
5. On Supabase, ensure the private `qc-evidence` bucket configuration is recreated from the repository migration after the public-schema restore. This restores bucket configuration, not object bytes.
6. Run the verification checklist below before directing any client or production traffic to the target.

`pg_restore` uses archive dependencies to order objects. If a manual/data-only recovery is ever required, the schema-derived order is: templates; template items; reports (including `template_snapshot`); report items, reviews, and samples; sample answers and attachments; idempotency keys; then evidence objects and reference checks.

Do not use `pg_restore --clean`, `--create`, `dropdb`, or schema/table drops by default. Those options can destroy unrelated or production state and require a separately approved, positively identified disposable target.

## JSON backup

Stop the Backend and choose a new external directory:

```powershell
Set-Location 'D:\QA-APPS-MOBILE\mock-api'
npm.cmd run backup:json -- --destination 'E:\qa-backups\json-20260824T120000+0700'
```

Optional `--source <directory>` is available for a disposable/non-default state directory. The command:

- requires `templates.json` and `reports.json`;
- captures `idempotency.json` or a canonical empty object;
- validates top-level records, duplicate IDs, idempotency claim hashes, and report references;
- writes SHA-256 checksums/counts to `manifest.json`;
- refuses destinations inside `D:\QA-APPS-MOBILE` or any existing destination;
- rejects a state change detected during its double read.

Back up `mock-api/.local-storage/qc-evidence` separately at the same recovery point when local evidence is used.

## JSON restore

Stop the Backend. Inspect the backup manifest and restore first to a disposable directory if possible:

```powershell
npm.cmd run restore:json -- --source 'E:\qa-backups\json-20260824T120000+0700' --target "$env:TEMP\qa-json-restore-drill" --confirm-replace
```

After verification, restore the runtime directory by omitting `--target`:

```powershell
npm.cmd run restore:json -- --source 'E:\qa-backups\json-20260824T120000+0700' --confirm-replace
```

The command requires an explicit source and `--confirm-replace`, refuses `APP_ENV=production`, validates all files/checksums/references before replacement, creates a pre-restore safety copy under the operating-system temporary directory, writes each file through a temporary file, and verifies the result. It prints the safety-copy path. Multi-file replacement is not atomic; if interrupted, keep writers stopped and recover from the printed safety copy.

## Evidence storage backup

### Local storage

Stop uploads and copy the entire evidence root to a new external directory so the `reports/...` hierarchy remains unchanged:

```powershell
$source = Resolve-Path 'D:\QA-APPS-MOBILE\mock-api\.local-storage\qc-evidence'
$destination = 'E:\qa-backups\qc-evidence-20260824T120000+0700'
if (Test-Path -LiteralPath $destination) { throw "Refusing to overwrite $destination" }
Copy-Item -LiteralPath $source -Destination $destination -Recurse
Get-ChildItem -LiteralPath $destination -Recurse -File | Get-FileHash -Algorithm SHA256
```

Restore the directory only while uploads are stopped. Copy into an empty isolated evidence root first, verify hashes and representative paths, then configure the disposable Backend to use it.

### Supabase Storage

The bucket is `qc-evidence`, private, and separate from the PostgreSQL dump. A complete binary backup requires an operator with approved Storage administrative/service-role access and a supported Supabase Storage listing/download or provider backup mechanism capable of retaining every object key and byte stream. Save an inventory containing object path, size, MIME type, and checksum where available.

No repository command currently exports the bucket, and no privileged production export was attempted in Phase 9. Database rows or `storage.objects` metadata alone cannot recreate image bytes. Treat remote binary backup and restore as operationally unverified until an authorized operator exercises it in an isolated project.

## Restore verification

Compare every result with counts/metadata recorded at backup time; do not assume fixed counts.

### PostgreSQL/provider

- Compare counts for all nine application tables listed in the backup section.
- Compare active/inactive template counts and IDs.
- Compare counts of reports with present/null `template_snapshot`; inspect representative historical snapshots.
- Confirm all FK constraints are valid and no report idempotency claim references a missing report.
- Verify report evidence metadata and canonical paths remain unchanged.
- Run `npm test`, `npm run check`, and `npm run check:contracts` against the restored provider configuration where safe.

Useful non-mutating checks:

```sql
select is_active, count(*) from public.qc_templates group by is_active order by is_active;
select count(*) filter (where template_snapshot is not null) as with_snapshot,
       count(*) filter (where template_snapshot is null) as without_snapshot
from public.qc_reports;
select count(*) as orphan_idempotency_keys
from public.api_idempotency_keys key
left join public.qc_reports report on report.id = key.resource_id
where report.id is null;
select conrelid::regclass as table_name, conname, convalidated
from pg_constraint
where contype = 'f' and connamespace = 'public'::regnamespace
order by table_name::text, conname;
```

### Application

- Call `/health`; require `alive=true`, expected providers/environment, and `ready=true` when dependencies are configured.
- Fetch the report list and one representative report detail without mutation.
- Confirm the detail retains samples, answers, admin review, `template_snapshot`, and evidence paths.
- Resolve representative evidence paths through the signed-URL endpoint when storage is available; fetch one result and verify it is the expected image.
- Investigate every missing evidence path. A syntactically valid path does not prove the object exists.

### JSON

- Confirm the restore command completes checksum/content verification.
- Compare `manifest.json` counts with restored arrays/object keys.
- Start a disposable Backend against the restored directory and perform the application checks above.

## Recovery scenarios

### Accidental report deletion

Restore the backup into an isolated database/directory, locate the report and every dependent row/embedded child, and verify its `template_snapshot`. Selectively reintroducing a report to a live system is a controlled data operation and has no automated repository command; preserve the dependency order and test it outside production first. If deletion cleanup removed evidence, recover those canonical object paths from the corresponding binary backup. A database-only backup cannot recover deleted images.

### Broken deployment or migration

Stop writes and direct traffic away from the affected target. Restore a pre-change database backup into a new isolated target and deploy the application revision recorded with that backup. Rolling back application code does not reverse database DDL or data transformations; use a reviewed forward repair or isolated database restore, never an assumed automatic migration rollback.

### Corrupted JSON local state

Stop the Backend, retain the corrupt directory for forensics, and run the JSON restore first against a disposable `--target`. After checks pass, restore the runtime directory with `--confirm-replace`; retain the printed pre-restore safety copy until recovery is accepted. Do not use `db:reset`/`db:reseed`, because they erase reports and idempotency claims.

### Database restored but evidence missing

Enumerate canonical evidence paths from representative/all reports and attempt signed-URL resolution. Restore matching binaries under exactly the same object keys from the evidence backup. If no binary backup exists, the images are unrecoverable; do not remove references or claim completeness without an explicit data-repair decision.

### Idempotency state inconsistent after recovery

Check every claim against its report. PostgreSQL restore should enforce the deferred FK; the JSON restore command rejects missing report references. Prefer restoring the matching report/idempotency backup pair. Clearing claims can allow a retry to create a duplicate, while `db:reset`/`db:reseed` deletes report state; neither is an automatic production repair. Any targeted cleanup requires an audited operator decision and a disposable rehearsal.

## Safety warnings

- Positively identify source and target before every command; never infer safety from an environment name alone.
- Stop writers for JSON/local storage and for a cross-service PostgreSQL-plus-evidence recovery point.
- Never overwrite the only backup. Verify checksums and retain an immutable copy.
- Never restore directly into production as the first drill.
- Never commit backup artifacts, evidence binaries, secrets, or real data.
- Seed/reset tooling is not restore tooling.
- Keep application code, migration revision, database snapshot, and evidence snapshot labeled as one recovery set.

## Known limitations

- PostgreSQL and evidence storage cannot be captured atomically with current repository tooling.
- JSON multi-file backup/restore requires stopped writers and is not transactionally atomic across files.
- Evidence-path validation proves syntax only, not object existence.
- Abandoned uploads and best-effort deletion cleanup can leave storage orphans.
- No automated selective report restore, remote bucket export, scheduler, retention policy, encryption workflow, or off-site replication is provided.
- Local safety copies use the operating-system temporary directory and must not be treated as durable backup retention.
- Phase 9 did not execute a privileged production database or Supabase Storage backup/restore drill.
