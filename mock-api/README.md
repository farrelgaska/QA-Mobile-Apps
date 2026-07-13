# Prototype QC Reports Mock API Backend

This is a lightweight local mock API server designed to simulate storage and retrieval of QC reports conforming to the shared data contract.

---

## 🚀 Getting Started

### 1. Install dependencies
From this directory, run:
```bash
npm install
```

### 2. Start the server
Run:
```bash
npm start
```
The server will be available at `http://localhost:3002`.

---

## 📡 API Endpoints

All endpoints use JSON payloads for request/response bodies and enable CORS out-of-the-box.

### 1. `GET /reports`
Retrieves all QC reports.

### 2. `GET /reports/:id`
Retrieves a specific QC report by ID. Returns a `404` error if not found.

### 3. `POST /reports`
Submits a new QC report. 
* Auto-generates a report ID if not present in the body.
* Overwrites/updates if a report with the same ID already exists (upsert behavior).
* Returns `201 Created` for new reports or `200 OK` for updates.

### 4. `PATCH /reports/:id`
Updates fields of an existing report.
* Returns `404` if the target ID does not exist.
* Performs a partial update (patch merge) on root-level fields and persists them back to `data/reports.json`.
* Validates report status against permitted lifecycle states: `DRAFT`, `SUBMITTED`, `NEEDS_FOLLOW_UP`, `APPROVED`.
