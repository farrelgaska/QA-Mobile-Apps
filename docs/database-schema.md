# Database schema

The first Supabase/Postgres migration is
`supabase/migrations/20260714000100_create_core_qa_schema.sql`. It models the
canonical contracts in `src/contracts/` without changing the existing public
string IDs used by the mobile and web applications.

## Relationships

```text
qc_templates (1) ──< qc_template_items
      │
      └──< qc_reports (template_id is nullable)
               ├──< qc_report_items
               ├──0..1 qc_report_admin_reviews
               └──< qc_report_attachments
                         └── optional parent qc_report_items row
```

- Deleting a template cascades to its template items. Reports keep their
  historical snapshot and have `template_id` set to null.
- Deleting a report cascades to its items, admin review, and attachments.
- Deleting a report item cascades to its item-scoped attachments.
- Template item IDs and report item IDs are scoped by their parent IDs, matching
  the API contracts and preserving legacy strings.

## Contract mapping

| Canonical contract | Database mapping |
| --- | --- |
| Template root | `qc_templates` |
| `checklist_items[]` on a template | `qc_template_items` |
| Template `is_active` | `qc_templates.is_active` |
| Template `workflow_status` | Separate `qc_templates.workflow_status`; never inferred from `is_active` |
| Template validation rule | `validation_type`, `validation_min_value`, `validation_max_value`, and `validation_exact_value` |
| Report root, staff, and location | Relational columns on `qc_reports` |
| Report `status` | `qc_reports.status` |
| Report checklist snapshot | `qc_report_items` |
| Report `admin_review` | One-to-one `qc_report_admin_reviews` |
| Report QC `conclusion` | `qc_report_admin_reviews.conclusion`, separate from report `status` |
| `general_photos[]` | `qc_report_attachments` rows with scope `GENERAL` |
| Item `item_photos[]` | `qc_report_attachments` rows with scope `ITEM` and a report-item foreign key |

`qc_templates.id`, `qc_template_items.id`, `qc_reports.id`, and
`qc_report_items.id` remain text. The schema does not replace public IDs with
UUIDs. Attachment rows use an internal identity because the contracts expose
photo URIs, not attachment IDs.

Empty canonical `template_id` strings should be persisted as SQL null so the
optional template foreign key remains valid. API adapters can map null back to
the contract's empty-string default when needed.

## Constraints and lifecycle rules

Checks mirror the contract enums for template type, workflow status, input
type, report status, item evaluation, and QC conclusion. A deferred constraint
trigger enforces the cross-table rule at transaction commit:

- `DRAFT` may have no admin review or a null conclusion.
- `SUBMITTED` is waiting for admin review and may have no admin review or a null
  conclusion.
- `NEEDS_FOLLOW_UP` and `APPROVED` require an explicit supported conclusion.
- Report status never determines the conclusion value. In particular,
  `APPROVED` does not imply `PASSED`.

| Report status | Admin review | Canonical conclusion |
| --- | --- | --- |
| `DRAFT` | Optional | `null`, `PASSED`, or `NOT_PASSED` |
| `SUBMITTED` | Optional | `null`, `PASSED`, or `NOT_PASSED` |
| `NEEDS_FOLLOW_UP` | Required | `PASSED` or `NOT_PASSED` |
| `APPROVED` | Required | `PASSED` or `NOT_PASSED` |

The mobile app creates `SUBMITTED` reports with a fresh, empty admin review.
The web review queue then moves a submitted report to `APPROVED` with `PASSED`
or to `NEEDS_FOLLOW_UP` with `NOT_PASSED`. The status and conclusion remain
independent contract fields: the database validates presence in final workflow
states but never derives a conclusion from a status.

The trigger is deferred so the Express persistence adapter can insert or update
the report and its review in either order inside one transaction.

## JSONB rationale

JSONB is limited to fields whose canonical contract is intentionally flexible:

- `general_info` differs by report and inspection type.
- `migration_metadata` preserves non-operational migration provenance and
  genuinely unknown legacy fields.
- `validation_exact_value` accepts any JSON-compatible value in the contract.
- Attachment `metadata` allows storage-provider details that are not business
  query fields.

Statuses, IDs, names, locations, review data, validation ranges, checklist
answers, choices, and photo ownership are relational columns rather than whole
record JSONB documents.

## RLS strategy

Row Level Security is enabled on every application table. This migration creates
no `anon` or `authenticated` policies, so client-side public access is denied.
Initial database access is expected only from the controlled Express backend
using the Supabase server secret/service role. That secret must never be sent to
mobile or web clients.

## Migration and rollback

Apply locally with the Supabase CLI when it is available, for example with
`supabase start` followed by `supabase db reset`. No remote project is linked or
deployed by this change.

Supabase migrations are forward-only in deployed environments. Before first
deployment, local rollback is a database reset or removal of the unapplied
migration. After deployment, create a new compensating migration that drops, in
order, the constraint triggers, attachment/review/item tables, report/template
tables, and finally the two trigger functions. Dropping these tables destroys
data and must never be done as an automatic application rollback.

## Multi-sample persistence

Migration `20260723000100_add_qc_report_samples.sql` adds
`qc_reports.sample_count`, `qc_report_samples`, and
`qc_report_sample_answers`. The migration is additive and does not change or
remove the existing report checklist tables. `sample_count` defaults to `1`,
so historical rows remain readable with an empty `samples` collection.

Samples and their answers are normalized instead of storing the entire sample
array in a report JSON document. This avoids duplicating the report snapshot,
supports updates to one sample independently, and makes identity, uniqueness,
and ordering enforceable in PostgreSQL. Explicit `position` columns preserve
API array order. Only the polymorphic `actual_value` uses JSONB, preserving
number, boolean, choice, text, and null values without coercion.

Sample answer checklist IDs are preserved as provided but are not foreign-keyed
to `qc_report_items`: the existing root checklist is a backward-compatible
snapshot and may be empty for a new sample-native report. The composite sample
answer key still prevents duplicate checklist item IDs within one sample.

Structured standard fields are stored alongside `standard_text`. The original
text is retained verbatim for display; `minimum_value` and `maximum_value` are
calculation inputs only. Parameter evaluation is limited to `NOT_EVALUATED`,
`WITHIN_STANDARD`, or `OUT_OF_STANDARD`. There is intentionally no sample-level
pass/fail column or database rule.

Sample and answer photo arrays contain only canonical Supabase `object_path`
values. Signed URLs and HTTP URLs are rejected by API and database checks.
