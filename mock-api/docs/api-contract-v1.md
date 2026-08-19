# QA Mobile Apps API Contract v1 Documentation

This document describes the canonical API v1 contracts, status configurations, legacy mappings, and versioning roadmap for the QA Mobile Apps backend.

---

## 1. API Route Versioning Roadmap
- **Planned Prefix**: `/api/v1`
- **Compatibility Note**: Current unversioned routes (e.g., `/reports`, `/templates`) remain active and temporarily compatible with existing React Web and Flutter clients.

---

## 2. Error Response Shape

All error responses from the API conform to the following standard JSON structure:

```json
{
  "error": "Detailed description of the error or validation failure"
}
```

- **HTTP 400 Bad Request**: Raised on syntax errors, non-object JSON payloads, or invalid parameter input.
- **HTTP 404 Not Found**: Raised when requesting or updating a template or report ID that does not exist.
- **HTTP 409 Conflict**: Raised when attempting to create a record with an ID that is already taken.
- **HTTP 500 Internal Server Error**: Raised on filesystem write or reading failures.

---

## 3. Canonical Template Contract

All database and version 1 API payloads for Master QA Templates conform to the structure below:

```json
{
  "id": "tiang_besi_7m_3_segmen",
  "type": "MATERIAL",
  "name": "Tiang Besi 7 Meter 3 Segmen",
  "description": "Pemeriksaan Fisik Tiang Besi 7 Meter 3 Segmen",
  "form_code": "TA-FR-048-010-01",
  "category": "Tiang Besi",
  "segment": "construction",
  "standard_code": "SPLN T3.001-1:2020",
  "is_active": true,
  "version": 1,
  "created_at": "2026-07-09T08:30:00Z",
  "updated_at": "2026-07-09T08:30:00Z",
  "checklist_items": [
    {
      "id": "item-1",
      "parameter_name": "Diameter Tiang",
      "input_type": "number",
      "standard_text": "Min 140mm",
      "unit": "mm",
      "is_required": true,
      "required_photo": true,
      "is_active": true,
      "is_critical": true,
      "position": 0,
      "choices": [],
      "validation_rule": {
        "type": "range",
        "min_value": 140,
        "max_value": 150,
        "exact_value": null
      }
    }
  ]
}
```

### Supported Status & Enum Values

- **Template Type**: `MATERIAL` or `WORK`
- **Checklist Item Input Type**: `number`, `text`, `choice`, or `boolean`

---

## 4. Canonical Report Contract

Quality control reports conform to the following schema structure:

```json
{
  "id": "QC-REP-2026-0041",
  "type": "MATERIAL",
  "template_id": "tiang_besi_7m_3_segmen",
  "form_code": "TA-FR-048-010-01",
  "title": "Pemeriksaan Tiang Besi 7 Meter 3 Segmen",
  "status": "APPROVED",
  "staff": {
    "name": "Yanuar Luthfi",
    "nik": "NIK-908271"
  },
  "location": {
    "site_id": "site-1",
    "site_name": "Gudang Material Utama",
    "area": "Sektor Timur",
    "detail_location": "Bekasi Site"
  },
  "general_info": {
    "poNumber": "PO-990"
  },
  "checklist_items": [
    {
      "id": "REP-001-C01",
      "parameter_name": "Ketebalan Galvanis",
      "input_type": "number",
      "standard_text": "Min 80 micron",
      "unit": "micron",
      "actual_value": "82",
      "staff_note": "",
      "item_photos": [],
      "admin_evaluation": "PASS",
      "admin_note": ""
    }
  ],
  "staff_note": "",
  "submitted_at": "2026-07-09T08:30:00Z",
  "admin_review": {
    "admin_note": "Laporan disetujui.",
    "conclusion": "PASSED",
    "reviewed_at": "2026-07-09T09:30:00Z"
  },
  "general_photos": [],
  "revision_number": 1,
  "migration_metadata": {
    "legacy_revision_history": []
  }
}
```

### Supported Status & Enum Values

- **Report Status**: `DRAFT`, `SUBMITTED`, `NEEDS_FOLLOW_UP`, or `APPROVED`
- **Checklist Admin Evaluation**: `PASS`, `FAIL`, `NEEDS_REVIEW`, or `PENDING`
- **Admin Conclusion**: `PASSED`, `NOT_PASSED`, or `null`

---

## 4.1 Multi-sample QC Material extension

The report contract is additive: the existing root `checklist_items` field is
unchanged. New and updated reports may include `sample_count` and an ordered
`samples` array:

```json
{
  "id": "QC-MAT-2026-0071",
  "type": "MATERIAL",
  "template_id": "tiang_besi_7m_3_segmen",
  "form_code": "TA-FR-048-010-01",
  "title": "Pemeriksaan Multi-sample Tiang Besi",
  "status": "DRAFT",
  "staff": {
    "name": "Staff Gudang",
    "nik": "NIK-100"
  },
  "location": {
    "site_id": "site-1",
    "site_name": "Gudang Material Utama",
    "area": "Sektor Timur",
    "detail_location": "Bay 4"
  },
  "general_info": {},
  "checklist_items": [],
  "staff_note": "",
  "admin_review": null,
  "general_photos": [],
  "sample_count": 2,
  "samples": [
    {
      "id": "sample-001",
      "sample_number": 1,
      "inspection_status": "COMPLETED",
      "checklist_answers": [
        {
          "checklist_item_id": "diameter",
          "input_type": "number",
          "actual_value": 3.1,
          "note": "Diukur pada titik tengah",
          "photo_paths": [
            "reports/QC-MAT-2026-0071/checklist/diameter/123e4567-e89b-42d3-a456-426614174000.jpg"
          ],
          "standard_text": "2,9 mm +15% / -12,5%",
          "standard_value": 2.9,
          "unit": "mm",
          "upper_tolerance": 15,
          "lower_tolerance": -12.5,
          "minimum_value": 2.5375,
          "maximum_value": 3.335,
          "evaluation_status": "WITHIN_STANDARD"
        }
      ],
      "notes": "Sampel pertama",
      "photo_paths": [],
      "created_at": "2026-07-23T02:00:00.000Z",
      "updated_at": "2026-07-23T02:10:00.000Z"
    },
    {
      "id": "sample-002",
      "sample_number": 2,
      "inspection_status": "IN_PROGRESS",
      "checklist_answers": [],
      "notes": "",
      "photo_paths": [],
      "created_at": "2026-07-23T02:15:00.000Z",
      "updated_at": "2026-07-23T02:15:00.000Z"
    }
  ],
  "revision_number": 1
}
```

Sample numbers and sample IDs must be positive/unique and stable within one
report. `inspection_status` supports `NOT_STARTED`, `IN_PROGRESS`, and
`COMPLETED`. Parameter `evaluation_status` supports `NOT_EVALUATED`,
`WITHIN_STANDARD`, and `OUT_OF_STANDARD`. No overall sample result is accepted,
derived, or persisted by this contract.

For report `PATCH`, a non-empty `samples` array merges by stable sample ID:
existing sample order and samples omitted from the patch are preserved, while
new IDs are appended in request order. Sending an explicit empty array clears
the sample collection.

`standard_text` is the original display string and is never replaced by the
structured calculation fields. Photo references must remain canonical Supabase
Storage `object_path` values; signed and HTTP URLs are not report data.

### Legacy report compatibility

An existing payload remains valid without the new fields:

```json
{
  "id": "QC-LEGACY-0042",
  "type": "MATERIAL",
  "title": "Laporan lama",
  "status": "DRAFT",
  "checklist_items": []
}
```

On read, the backend exposes sensible additive defaults:

```json
{
  "sample_count": 1,
  "samples": []
}
```

The legacy root checklist remains readable and is not copied into a synthetic
sample.

### QC Material review request snapshot

A Staff Warehouse review request is stored as report-level evidence. It records
the failed samples at the moment the request is made; it is not an Admin
decision and does not change `status` or `admin_review`.

```json
{
  "review_requested": true,
  "review_requested_at": "2026-07-23T04:00:00.000Z",
  "review_requested_by_role": "STAFF_WAREHOUSE",
  "review_failed_sample_count": 2,
  "review_failed_sample_ids": ["sample-001", "sample-002"],
  "review_failed_sample_numbers": [1, 2]
}
```

When no request exists, the additive defaults are:

```json
{
  "review_requested": false,
  "review_requested_at": null,
  "review_requested_by_role": null,
  "review_failed_sample_count": null,
  "review_failed_sample_ids": [],
  "review_failed_sample_numbers": []
}
```

For a requested snapshot, the timestamp must be valid, the role must be exactly
`STAFF_WAREHOUSE`, and both unique sample arrays must contain at least two
entries. `review_failed_sample_count` must equal both array lengths. Review
requests are supported only on `MATERIAL` reports. Invalid input uses the
existing HTTP 400 body:

```json
{
  "error": "review_failed_sample_ids: failed sample IDs must be unique"
}
```

Once stored, this snapshot is immutable. PATCH requests that omit these fields
preserve it, while attempts to clear or overwrite it return HTTP 400. The
backend still reads the legacy mobile keys in `general_info`
(`qcReviewRequested`, `qcReviewRequestedAt`,
`qcReviewFailedSampleIds`, `qcReviewFailedSampleNumbers`, and
`qcFailedSampleCount`) and promotes a valid legacy snapshot in API output. The
legacy keys are retained for backward compatibility.

Legacy-compatible input example:

```json
{
  "general_info": {
    "qcReviewRequested": "true",
    "qcReviewRequestedAt": "2026-07-23T04:00:00.000Z",
    "qcReviewFailedSampleIds": "[\"sample-001\",\"sample-002\"]",
    "qcReviewFailedSampleNumbers": "[1,2]",
    "qcFailedSampleCount": "2",
    "qcReviewRequestEligible": "true"
  }
}
```

---

## 5. Legacy Property Alias Mapping

| Legacy Property | Canonical Property | Notes |
| :--- | :--- | :--- |
| **`parameterName`** or **`name`** | **`parameter_name`** | Used in checklist parameters. |
| **`standardText`** or **`standardLabel`** | **`standard_text`** | Used in checklist parameters. |
| **`required`** | **`is_required`** | Checklist items requirement status. |
| **`requiredPhoto`** | **`required_photo`** | Checklist photo requirement status. |
| **`minVal`** / **`maxVal`** | **`validation_rule.min_value`** / **`validation_rule.max_value`** | Normalized into rule object. |
| **`booleanCheck`** | **`boolean`** | Normalizes input type. |
| **`isCritical`** | **`is_critical`** | Critical status flag. |
| **`isActive`** or **`isActive`** (missing) | **`is_active`** | Default to `true`. |
| **`revision_history`** | **`migration_metadata.legacy_revision_history`** | Maintained as metadata, not nested recursively. |
| **`Lulus`** / **`Tidak Lulus`** | **`PASSED`** / **`NOT_PASSED`** | Normalized admin conclusion review values. |
