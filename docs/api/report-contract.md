# Shared Report Data Contract

This document defines the single, unified JSON data contract for Quality Control (QC) reports shared between the Flutter mobile application and the React Web Admin portal.

## Data Structure

### Main Report Contract

| Key | Type | Core Values / Format | Description |
|---|---|---|---|
| `id` | `string` | e.g. `QC-MAT-2026-0041` | Unique identifier for the report. |
| `type` | `string` | `MATERIAL` \| `WORK` | The QC category of the report. |
| `templateId` | `string` | e.g. `tiang_besi_7m` | Reference to the checklist template used. |
| `formCode` | `string` | e.g. `TA-FR-048-010-01` | Administrative form code. |
| `title` | `string` | e.g. `Tiang Besi 7M 3 Segmen` | Display name of the report. |
| `status` | `string` | `DRAFT` \| `SUBMITTED` \| `NEEDS_FOLLOW_UP` \| `APPROVED` | Current lifecycle state of the report. |
| `staff` | `object` | `{ name: string, nik: string }` | Identity of the field staff who checked/submitted the report. |
| `location` | `object` | `{ siteId: string, siteName: string, area: string, detailLocation: string }` | Site location details. |
| `generalInfo` | `map<string, string>` | e.g. `{"poNumber": "PO-990"}` | Dynamic key-value pairs for general/metadata fields. |
| `checklistItems` | `array<object>` | List of `ChecklistItem` | Individual check items and results. |
| `staffNote` | `string` | e.g. `Aman terkendali` | Note added by the field staff. |
| `submittedAt` | `string` | ISO 8601 Datetime String | Timestamp when the report was submitted. |
| `revisionNumber` | `integer` | e.g. `1` | Starts at 1, increments on resubmission. |
| `adminReview` | `object` | `{ adminNote: string, reviewedAt?: string, conclusion?: string, reviewedBy?: string }` | Evaluation details filled by the Admin. |

### Checklist Item Structure

| Key | Type | Core Values / Format | Description |
|---|---|---|---|
| `id` | `string` | e.g. `item-1` | Unique item identifier in the template. |
| `parameterName` | `string` | e.g. `Ketebalan segment` | Display text of the parameter. |
| `inputType` | `string` | `number` \| `text` \| `choice` | Input type of the parameter. |
| `standardText` | `string` | e.g. `min 4.0 mm` | Definition of passing standard. |
| `unit` | `string` | e.g. `mm` (optional) | Metric unit. |
| `actualValue` | `string` | e.g. `4.2` | The value entered by the field staff. |
| `staffNote` | `string` | e.g. `Karat tipis` | Note entered by the staff. |
| `photoUrls` | `array<string>` | List of URLs | Photo uploads for this checklist item. |
| `adminEvaluation` | `string` | `PASS` \| `FAIL` \| `NEEDS_REVIEW` | Admin's evaluation status. |
| `adminNote` | `string` | e.g. `Perlu diukur ulang` | Specific revision note from the Admin. |

---

## JSON Payload Example

```json
{
  "id": "QC-MAT-2026-0043",
  "type": "MATERIAL",
  "templateId": "tiang_galvanis_6m_tanpa_sambungan",
  "formCode": "TA-FR-048-010-03",
  "title": "Tiang Galvanis 6M Tanpa Sambungan",
  "status": "NEEDS_FOLLOW_UP",
  "staff": {
    "name": "Yanuar Luthfi",
    "nik": "NIK-908271"
  },
  "location": {
    "siteId": "site-1",
    "siteName": "Gudang Material Utama",
    "area": "Sektor 4 - Area Utara",
    "detailLocation": "Gudang Utama B-1"
  },
  "generalInfo": {
    "poNumber": "PO-2026-092",
    "poDate": "2026-06-12",
    "doNumber": "DO-889013",
    "vendorName": "PT Global Galvanis"
  },
  "checklistItems": [
    {
      "id": "tb-galv-1",
      "parameterName": "Lapisan anti karat / galvanis",
      "inputType": "choice",
      "standardText": "Mulus bebas karat",
      "unit": "",
      "actualValue": "Ada karat permukaan",
      "staffNote": "Ditemukan bercak karat permukaan pada ujung sambungan",
      "photoUrls": [
        "https://images.unsplash.com/photo-1590069261209-f8e9b8642343?auto=format&fit=crop&w=150&q=80"
      ],
      "adminEvaluation": "FAIL",
      "adminNote": "Harap lakukan coating ulang anti karat."
    }
  ],
  "staffNote": "Ditemukan karat ringan di ujung tiang. Perlu pelapisan ulang.",
  "submittedAt": "2026-07-13T01:30:00Z",
  "revisionNumber": 1,
  "adminReview": {
    "adminNote": "Harap lakukan coating ulang anti karat.",
    "reviewedAt": "2026-07-13T02:00:00Z",
    "conclusion": "Tidak Lulus"
  }
}
```
