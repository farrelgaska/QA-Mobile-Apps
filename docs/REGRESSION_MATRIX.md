# QA Digitalization Phase 6 Regression Matrix

Verified against the current Mobile, Web Admin, and Backend source and automated tests on 2026-08-24. This is the authoritative Phase 6 matrix; deployed storage integrity is deferred to Phase 7.

## Status

- **PASS** — deterministic automated coverage protects the owning rule and any material client contract.
- **PARTIAL** — useful automated coverage exists, but one applicable client or integration boundary lacks a direct regression test.
- **MISSING** — an applicable critical rule has no useful automated coverage.
- **NOT APPLICABLE** — the scope does not own or consume the rule.

## Matrix

| ID | Area | Scenario | Mobile | Web | Backend | Automated test | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| REG-AUTH-001 | Authentication | Existing login screen and API authentication assumptions | PARTIAL | PARTIAL | PASS | `mobile/test/widget_test.dart`; `backend/test/auth-middleware.test.js` | PARTIAL | Login UI and token middleware are tested; no real shared session/SSO integration exists. |
| REG-AUTH-002 | Roles | Staff Warehouse can create/submit; only Admin can review | PASS | PASS | PASS | `mobile/test/shared/models/user_role_test.dart`; `web/test/roles.test.ts`; `backend/test/auth-middleware.test.js` | PASS | Legacy QA Staff labels normalize to Staff Warehouse. |
| REG-AUTH-003 | Authentication | Missing or invalid API credentials return canonical 401 | N/A | N/A | PASS | `backend/test/auth-middleware.test.js`; `backend/test/repositories/error-contract.test.js` | PASS | Client parsing is covered by REG-ERR-001. |
| REG-TPL-001 | Templates | Material and Work template identifiers and wire fields map canonically | PASS | PARTIAL | PASS | `mobile/test/shared/models/qc_template_contract_test.dart`; `backend/test/repositories/template-contract.test.js`; `backend/test/repositories/template-http-contract.test.js` | PARTIAL | Web mapping compiles and is exercised indirectly, but has no focused mapping test. |
| REG-TPL-002 | Templates | Active templates support creation; inactive templates reject new reports | N/A | PARTIAL | PASS | `backend/test/repositories/template-lifecycle.test.js`; `backend/test/repositories/postgres-template-lifecycle.test.js` | PASS | Backend owns the creation rule; Web exposes lifecycle controls without focused UI tests. |
| REG-TPL-003 | Templates | Number, choice, boolean, and text parameter metadata remain canonical | PASS | PARTIAL | PASS | `mobile/test/shared/models/qc_template_contract_test.dart`; `backend/test/repositories/template-contract.test.js`; `backend/test/repositories/postgres-template-choice-options.test.js` | PASS | Backend and Mobile protect the consumed contract. |
| REG-TPL-004 | Templates | Report creation stores an immutable `template_snapshot` | N/A | N/A | PASS | `backend/test/repositories/template-lifecycle.test.js`; `backend/test/repositories/postgres-template-lifecycle.test.js` | PASS | Covered for JSON and PostgreSQL providers. |
| REG-TPL-005 | Templates | Mobile parses the historical snapshot used by report detail | PASS | N/A | PASS | `mobile/test/shared/models/qc_report_model_test.dart`; `backend/test/repositories/template-lifecycle.test.js` | PASS | Snapshot mapping is protected independently of current template state. |
| REG-TPL-006 | Templates | Web historical interpretation is independent of current template mutations | N/A | MISSING | PASS | `backend/test/repositories/template-lifecycle.test.js`; `web/test/material-report-presentation.test.ts` | PARTIAL | Web renders persisted report/sample fields but does not type or consume `template_snapshot`. |
| REG-QC-001 | QC Material | Required general fields and invalid sample counts block progression | PASS | N/A | N/A | `mobile/test/shared/providers/qc_material_multi_step_provider_test.dart` | PASS | Includes every required general field and numeric validation. |
| REG-QC-002 | QC Material | Parameters represent compliant, non-compliant, and incomplete states | PASS | PASS | PASS | `mobile/test/core/utils/qc_validation_helper_test.dart`; `web/test/material-report-presentation.test.ts`; `backend/test/repositories/multi-sample-reports.test.js` | PASS | Staff and Admin evaluations remain independent. |
| REG-QC-003 | QC Material | Supported numeric values, including negative bounds, are accepted and evaluated | PASS | N/A | PASS | `mobile/test/shared/providers/qc_material_sample_evaluation_test.dart`; `backend/test/repositories/qc-material-numeric-bounds.test.js` | PASS | Structured bounds are authoritative; standard display text is preserved. |
| REG-QC-004 | QC Material | Multi-sample values, notes, statuses, and photos remain sample-isolated | PASS | PASS | PASS | `mobile/test/shared/providers/qc_material_multi_step_provider_test.dart`; `web/test/material-report-presentation.test.ts`; `backend/test/repositories/multi-sample-reports.test.js` | PASS | Stable IDs and sample ordering are covered. |
| REG-QC-005 | QC Material | Two failed samples preserve STOP/review-request evidence | PASS | PASS | PASS | `mobile/test/shared/providers/qc_material_sample_evaluation_test.dart`; `web/test/material-report-presentation.test.ts`; `backend/test/repositories/review-requests.test.js` | PASS | Review request remains distinct from Admin workflow status. |
| REG-QC-006 | QC Pekerjaan | Compliant/non-compliant input and required failure notes are enforced | PASS | PASS | PASS | `mobile/test/shared/providers/qc_pekerjaan_form_provider_test.dart`; `web/test/work-report-detail.test.ts`; `backend/test/repositories/admin-parameter-notes.test.js` | PASS | Non-whitespace notes are required where applicable. |
| REG-QC-007 | QC Pekerjaan | Required fields and evidence block incomplete submission | PASS | N/A | PASS | `mobile/test/shared/providers/qc_pekerjaan_form_provider_test.dart`; `backend/test/repositories/template-contract.test.js` | PASS | Required-photo template metadata remains enforced by Mobile. |
| REG-EVD-001 | Evidence | JPEG/PNG/HEIC processing, orientation, downscale, and 2 MB limit | PASS | N/A | N/A | `mobile/test/shared/services/qc_photo_processor_test.dart`; `mobile/test/shared/services/qc_photo_processor_web_test.dart` | PASS | Corrupt and failed conversion paths fail safely. |
| REG-EVD-002 | Evidence | Capture time/location metadata survives valid capture and safe fallback | PASS | PASS | PASS | `mobile/test/shared/services/qc_capture_location_service_test.dart`; `web/test/qc-evidence-capture-metadata.test.ts`; `backend/test/repositories/qc-evidence-capture-metadata.test.js` | PASS | Missing location does not invalidate an otherwise valid photo. |
| REG-EVD-003 | Evidence | Upload rejects missing, empty, spoofed, unsafe, unsupported, or oversized input | PASS | N/A | PASS | `mobile/test/shared/providers/qc_material_form_provider_test.dart`; `backend/test/repositories/qc-evidence-upload.test.js` | PASS | Trust-boundary validation remains backend-owned. |
| REG-EVD-004 | Evidence | Canonical object paths remain persisted; signed URLs are display-only | PASS | PASS | PASS | `mobile/test/shared/providers/qc_material_form_provider_test.dart`; `web/test/material-report-presentation.test.ts`; `backend/test/repositories/multi-sample-reports.test.js` | PASS | Signed URLs are never serialized into report PATCH payloads. |
| REG-EVD-005 | Evidence | Signed URL batches preserve valid results and report missing objects safely | PASS | PASS | PASS | `mobile/test/shared/widgets/photo_grid_processing_test.dart`; `web/test/material-report-presentation.test.ts`; `backend/test/repositories/qc-evidence-upload.test.js` | PASS | Current functional contract only; storage integrity is Phase 7. |
| REG-SUB-001 | Submission | Valid QC Material submission persists one report | PASS | N/A | PASS | `mobile/test/shared/providers/qc_material_form_provider_test.dart`; `backend/test/repositories/json-contract.test.js` | PASS | HTTP create semantics are covered by REG-SUB-004. |
| REG-SUB-002 | Submission | Valid QC Pekerjaan submission persists one report | PASS | N/A | PASS | `mobile/test/shared/providers/qc_pekerjaan_form_provider_test.dart`; `backend/test/repositories/json-contract.test.js` | PASS | Uses the shared report contract. |
| REG-SUB-003 | Submission | Invalid or incomplete reports never invoke persistence | PASS | PASS | PASS | `mobile/test/shared/providers/qc_material_multi_step_provider_test.dart`; `web/test/material-report-presentation.test.ts`; `backend/test/repositories/multi-sample-reports.test.js` | PASS | Admin decision validation also blocks mutation. |
| REG-SUB-004 | Submission | Duplicate report IDs return `REPORT_ALREADY_EXISTS` / HTTP 409 | PASS | PASS | PASS | `mobile/test/core/services/api_service_test.dart`; `web/test/report-api-error.test.ts`; `backend/test/repositories/error-contract.test.js` | PASS | Both clients accept the canonical error code. |
| REG-SUB-005 | Idempotency | First request creates; same key/payload replays with HTTP 200 and replay header | PASS | N/A | PASS | `mobile/test/core/services/api_service_test.dart`; `backend/test/repositories/idempotency-http.test.js`; `backend/test/repositories/idempotency.test.js` | PASS | `Idempotency-Key` remains optional. |
| REG-SUB-006 | Idempotency | Changed payload conflicts; empty/whitespace/over-limit keys are rejected | PASS | N/A | PASS | `mobile/test/shared/utils/request_fingerprint_test.dart`; `backend/test/repositories/idempotency-http.test.js`; `backend/test/repositories/idempotency-middleware.test.js` | PASS | Valid trimmed length is 1–255. |
| REG-SUB-007 | Idempotency | Mobile retry reuses intent; semantic edits rotate the key | PASS | N/A | PASS | `mobile/test/shared/providers/qc_material_upload_concurrency_test.dart`; `mobile/test/shared/providers/qc_pekerjaan_form_provider_test.dart`; `backend/test/utils/fingerprint.test.js` | PASS | Transient/server-generated fields are excluded from fingerprints. |
| REG-SUB-008 | Submission | Concurrent/double submit cannot create duplicate persistence calls | PASS | N/A | PASS | `mobile/test/shared/providers/qc_material_upload_concurrency_test.dart`; `backend/test/repositories/idempotency.test.js` | PASS | UI/provider lock and backend claim semantics both protect the flow. |
| REG-SUB-009 | Submission | Upload/report failure keeps retryable evidence and avoids duplicate upload | PASS | N/A | PASS | `mobile/test/shared/providers/qc_material_form_provider_test.dart`; `backend/test/repositories/qc-evidence-upload.test.js` | PASS | Failed submission does not fabricate a local persisted report. |
| REG-RPT-001 | Reports | Lists expose current statuses and exclude drafts from Admin views | PASS | PASS | PASS | `mobile/test/core/services/api_service_test.dart`; `mobile/test/core/utils/report_statistics_test.dart`; `web/test/report-api-error.test.ts`; `backend/test/repositories/json-contract.test.js` | PASS | Admin excludes drafts while preserving submitted and approved reports. |
| REG-RPT-002 | Reports | Detail refresh avoids stale workflow state | PASS | MISSING | N/A | `mobile/test/features/reports/report_status_refresh_test.dart` | PARTIAL | Mobile sends `Cache-Control: no-cache`; Web detail currently relies on list/context state. |
| REG-RPT-003 | Reports | Draft, submitted, follow-up, and approved statuses render canonically | PASS | PASS | PASS | `mobile/test/features/reports/report_status_refresh_test.dart`; `web/test/material-report-presentation.test.ts`; `backend/test/repositories/review-requests.test.js` | PASS | Sampling STOP metadata does not impersonate workflow status. |
| REG-RPT-004 | Reports | Multi-sample and legacy Material/Work history render without data leakage | PASS | PASS | PASS | `mobile/test/features/reports/qc_material_report_detail_test.dart`; `web/test/material-report-presentation.test.ts`; `web/test/work-report-detail.test.ts`; `backend/test/repositories/multi-sample-reports.test.js` | PASS | Legacy root checklist remains readable. |
| REG-RPT-005 | Admin review | Approve/follow-up requires complete decisions and notes and preserves canonical evidence | N/A | PASS | PASS | `web/test/material-report-presentation.test.ts`; `backend/test/repositories/sample-admin-reviews.test.js`; `backend/test/repositories/admin-parameter-notes.test.js` | PASS | Failed PATCH cannot leave an optimistic status. |
| REG-ERR-001 | API errors | Clients parse canonical top-level errors while accepting the nested mirror | PASS | PASS | PASS | `mobile/test/core/services/api_service_test.dart`; `web/test/report-api-error.test.ts`; `backend/test/repositories/error-contract.test.js` | PASS | Nested `error.code/message` remains a temporary compatibility dependency. |
| REG-ERR-002 | API errors | Validation, conflict, timeout, and internal errors map to safe codes/statuses | PARTIAL | PARTIAL | PASS | `backend/test/repositories/error-contract.test.js`; `backend/test/repositories/postgres-report-read-retry.test.js` | PARTIAL | Clients parse the envelope; not every code has a dedicated UI-message assertion. |
| REG-SEED-001 | Seed/reset | Seed converges canonical templates while preserving reports and idempotency | N/A | N/A | PASS | `backend/test/seed/json-seed.test.js`; `backend/test/seed/postgres-seed.test.js` | PASS | Provider-specific behavior is tested without production mutation. |
| REG-SEED-002 | Seed/reset | Reset clears reports/idempotency and restores canonical templates | N/A | N/A | PASS | `backend/test/seed/json-seed.test.js`; `backend/test/seed/postgres-seed.test.js` | PASS | Includes reseed semantics. |
| REG-SEED-003 | Seed/reset | Production/staging destructive-command guards fail closed | N/A | N/A | PASS | `backend/test/seed/guard.test.js`; `backend/test/config/env.test.js` | PASS | No destructive command was executed during Phase 6. |

## Coverage summary

| Total | PASS | PARTIAL | MISSING | BLOCKED |
|---:|---:|---:|---:|---:|
| 40 | 35 | 5 | 0 | 0 |

## Cross-scope contract findings

1. Backend errors are canonical at top level (`code`, `message`, `status`) and temporarily mirrored under `error`. Mobile and Web now parse the top level first and retain nested compatibility.
2. Backend and Mobile carry `template_snapshot`; Web historical pages render persisted report/sample values and do not consume the snapshot directly. This is functional today but leaves Web snapshot-specific coverage partial.
3. Report, template, status, notes, samples, and evidence object-path shapes align across the three scopes. Signed display URLs remain transient and are not persisted.
4. Mobile performs an authoritative no-cache detail fetch. Web Admin currently renders report detail from its reports context/list state, so equivalent freshness is not directly protected.

## Known limitations

- Phase 7: deployed storage/object integrity and provider parity are not asserted here.
- Phase 8: production observability is not part of this matrix.
- Phase 9: operational backup/restore drills are not part of this matrix.
- Phase 10: terminology cleanup remains separate from contract correctness.
- Later product scope: SSO/session integration, broader security hardening, and template business-data completion.

## Verification commands

- Backend: `npm test`, `npm run check`, `npm run check:contracts`
- Mobile: `flutter test`, `flutter analyze lib test`
- Web: all six `node --test` files, `npm run lint`, `npm run build`

## Verification results

- Backend: focused contract slice 13/13; repository suite 156/156; auth/config/seed/fingerprint suite 44/44; `check` and `check:contracts` passed.
- Mobile: focused API 12/12 and report-model 3/3; full suite 187/187; `flutter analyze lib test` found no issues.
- Web: API/list 2/2, evidence 7/7, and Admin report presentation 35/35; all six files 57/57; lint passed; production build passed with the known large-chunk warning.
