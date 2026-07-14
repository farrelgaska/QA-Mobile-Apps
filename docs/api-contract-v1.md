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
