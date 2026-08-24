# Storage Integrity â€” Phase 7

Audit date: 2026-08-24. Scope: QC evidence upload, object naming, report
references, display URL resolution, deletion, reset/reseed, and safe production
sampling across Mobile, Web, and Backend.

## Storage architecture

1. Mobile captures and locally processes an image, then sends multipart
   `POST /uploads/qc-evidence` with `report_id`, `category`, and `item_id`.
2. The Backend is the trust boundary. It enforces one file, a 2 MB maximum,
   JPEG/PNG/WebP/HEIC MIME allowlisting, content signature detection, MIME/content
   agreement, and safe identifier segments.
3. The Backend generates the object key; the client filename is never used:
   `reports/{reportId}/general/{uuid}.{ext}` or
   `reports/{reportId}/checklist/{itemId}/{uuid}.{ext}`.
4. `STORAGE_PROVIDER=local` writes below
   `mock-api/.local-storage/qc-evidence`. `STORAGE_PROVIDER=supabase` writes to
   the private `qc-evidence` bucket with `upsert: false`.
5. Reports persist canonical object paths, primarily in sample `photo_paths`
   and checklist-answer `photo_paths`; legacy aggregate fields are
   `general_photos` and checklist-item `item_photos`.
6. Mobile and Web call `POST /uploads/qc-evidence/signed-urls` for display.
   Signed URLs are held only in display maps and are not serialized back into
   reports.

## Provider behavior

| Concern | Local | Supabase |
|---|---|---|
| Upload collision | UUID key; filesystem write | UUID key; `upsert: false` |
| Display URL | Non-production `/mock-storage/...` URL | Private signed URL, 3600 seconds |
| Missing object | Returned in `failed_paths` | Returned in `failed_paths` |
| Report delete | Best-effort removal of current canonical paths | Best-effort removal of current canonical paths |
| Production static route | Disabled | Not applicable |

## Integrity findings

- **PASS** â€” Upload validation rejects missing, empty, oversized, unsupported,
  spoofed, or traversal-shaped input before storage mutation. Exact 2 MB files
  remain accepted.
- **PASS** â€” Object keys are backend-generated, canonical, report-scoped, and
  independent of the original filename.
- **PASS** â€” Mobile and Web retain canonical paths for persistence and use
  temporary URLs only for display. Missing URLs degrade to the existing image
  placeholder rather than changing report data.
- **FIXED** â€” The documented explicit `STORAGE_PROVIDER=local` setting is now
  accepted by environment parsing.
- **FIXED** â€” Local signed-URL resolution now checks file existence and reports
  a missing canonical path in `failed_paths` instead of issuing a guaranteed
  404 URL.
- **FIXED** â€” JSON/local report deletion now matches PostgreSQL deletion by
  attempting best-effort evidence removal. Deletion collection accepts only
  canonical paths, so a crafted legacy reference cannot escape the evidence
  root.
- **LIMITATION** â€” Report create/update validates canonical sample evidence
  syntax but does not prove object existence at the persistence boundary.
  Existence is detected later during signed-URL resolution.
- **LIMITATION** â€” An upload that succeeds before report submission fails can
  become orphaned. Mobile caches a successful object path for an in-memory
  retry, but a lost upload response, abandoned form, or process restart can
  still leave an object. There is no bucket-to-report reconciliation job.
- **LIMITATION** â€” Report deletion is intentionally best effort after database
  commit. A storage outage leaves an orphan and logs a warning rather than
  turning a successful report deletion into HTTP 500.
- **LIMITATION** â€” `db:reset` and `db:reseed` reset report/template data only;
  they do not enumerate or delete storage objects. This avoids unbounded bucket
  deletion but requires an explicit retention policy before operational cleanup.

## Production verification

Read-only checks against `https://qa-mobile-api.vercel.app` used no credentials
and performed no mutation or bucket enumeration.

- **PASS** â€” `/health` returned HTTP 200 with `data_provider=postgres` and
  `database_reachable=true`.
- **PASS** â€” Uploaded report
  `QC-MAT-1787209635417000-110536088808bc37975fb5eea9c95213` exposed canonical
  active evidence paths. Three sampled active paths resolved successfully; one
  sampled object was retrieved as HTTP 200 `image/jpeg` (131,978 bytes).
- **LIMITATION** â€” Seeded report `QC-MAT-TEST-001-submitted` contains three
  canonical fixture paths, but all three resolve as missing. These are seed-data
  placeholders, not evidence uploaded through the production flow.
- **UNVERIFIED_REMOTE** â€” Private bucket policies, complete object inventory,
  and total orphan count cannot be safely proven from public endpoints without
  privileged storage access.

## Lifecycle policy requiring an owner decision

Before automated cleanup is introduced, define retention for abandoned uploads,
deleted reports, reset/reseed operations, legal/audit holds, and the seeded
fixture paths above. Any reconciler must start in report-only/dry-run mode and
must never infer deletions from a partial database or bucket scan.

## Phase 7 verdict

`PASS_WITH_KNOWN_LIMITATIONS`
