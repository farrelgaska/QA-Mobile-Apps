# Observability

The Backend writes newline-delimited JSON through the runtime console. No new
logging dependency or monitoring service is required. The existing optional
Sentry integration initializes only when `SENTRY_DSN` is configured; otherwise
structured local/platform logs remain the source of truth.

## Log contract

Every log contains:

```json
{"timestamp":"2026-08-24T00:00:00.000Z","level":"info","event":"http_request_completed"}
```

Request completion logs add `request_id`, `method`, `path`, `status`, and
`duration_ms`. Business events add only applicable safe identifiers such as
`report_id`, `template_id`, `storage_provider`, or `object_path`.

Levels are intentionally simple:

- successful requests: `info`
- successful `/health` probes: `debug`
- expected 4xx/domain failures: `warn`
- 5xx failures: `error`

Production error logs omit stack traces. Non-production 5xx logs may include a
stack for local diagnosis, but never request bodies or headers.

## Request IDs

- An incoming `X-Request-Id` is reused only when it is 1–128 characters and
  matches `[A-Za-z0-9][A-Za-z0-9._:-]*`.
- Invalid, empty, or oversized values are replaced with a server UUID.
- The selected ID is attached to `req.requestId`, included in lifecycle/error
  events, and returned in the `X-Request-Id` response header.
- CORS allows and exposes `X-Request-Id`.
- Report IDs and idempotency keys are never used as request IDs.

## Important events

| Event | Meaning | Useful fields |
|---|---|---|
| `application_started` | Backend listener started | environment, providers, port |
| `http_request_completed` | One completion record per request | request fields and duration |
| `request_failed` | Structured non-idempotency failure | request fields, status, code, operation |
| `report_created` | First successful report persistence | report/template ID, report status, idempotency state |
| `idempotency_replay` | Existing result returned | report ID, short key fingerprint |
| `idempotency_conflict` | Key reused for different input | report ID, short key fingerprint |
| `report_deleted` | Report deletion completed | report ID |
| `evidence_upload_succeeded` | Evidence object stored | report ID, canonical path, MIME, size, provider |
| `evidence_resolution_partial` | Some requested objects were missing | requested/failed counts, provider |
| `storage_cleanup_failed` | Best-effort report evidence cleanup failed | report ID, object count, provider |
| `database_idle_client_error` | PostgreSQL idle client failed | database error code/type |
| `json_storage_write_bypassed` | Local JSON disk write failed; memory state retained | resource type, error type |

The idempotency fingerprint is the first 16 hexadecimal characters of SHA-256;
the replay-capable key itself is never logged.

## Health response

`GET /health` remains HTTP 200 as a process/liveness endpoint and exposes only:

- `status`: `OK` or `DEGRADED`
- `timestamp`
- `alive`
- `ready`
- `environment`
- `data_provider`
- `database_reachable`
- `storage_provider`
- `storage_configured`

`storage_configured` is configuration readiness, not a remote bucket probe.
Production local storage is reported unready because `/mock-storage` is disabled
there. Database URLs, Supabase URLs, credentials, auth tokens, and storage keys
are never returned.

## Never log

- `Authorization`, cookies, sessions, or full idempotency keys
- request/response bodies or Staff/Admin report content
- raw image bytes or multipart bodies
- database URLs, Supabase service keys, or environment secrets
- signed URLs, because they contain temporary access tokens

## Failed report submission workflow

1. Obtain `X-Request-Id` from the failed API response in device/browser network
   diagnostics or the calling integration.
2. Search Backend logs for that exact `request_id`.
3. Read `request_failed` for the stable `code` and safe operation context.
4. Read the matching `http_request_completed` event for route, status, and
   duration.
5. For retries, compare `idempotency_replay` or `idempotency_conflict` using the
   short fingerprint; never request the raw key from a user.
6. For evidence failures, correlate `evidence_upload_succeeded`,
   `evidence_resolution_partial`, and `storage_cleanup_failed` by report ID.

## Known limitations

- There is no centralized log aggregation, retention policy, dashboard, or
  alerting in repository scope.
- `/health` does not perform a bucket read/write probe and therefore cannot prove
  remote object-storage reachability.
- Mobile and Web do not persist or prominently display request IDs. Browser/device
  network diagnostics can read the header, but a formal support workflow may
  justify capturing it in client error objects later.
- This layer provides logs, not application metrics or distributed tracing.
