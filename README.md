# QA Mobile Apps

QA Mobile Apps is an integrated Quality Assurance system designed to manage **QC Material** and **QC Pekerjaan** workflows.

<<<<<<< HEAD
The system consists of a Flutter application for QA Staff, a React-based Admin Dashboard, an Express API, PostgreSQL, and private object storage.

> Dokumentasi utama: **[Handover Teknis lengkap](docs/HANDOVER.md)**.

## Demo

| Aplikasi | URL |
|---|---|
| Admin Web | [https://qa-mobile-web.vercel.app](https://qa-mobile-web.vercel.app) |
| Mobile Web | [https://qa-mobile-app.vercel.app](https://qa-mobile-app.vercel.app) |

URL tersebut adalah deployment demo yang terdokumentasi. Repository tidak
membuktikan production branch, Root Directory, Build Command, environment
assignment, domain API, maupun pengaturan Vercel lainnya.

## Komponen utama

| Komponen | Pengguna | Tanggung jawab |
|---|---|---|
| QA Staff Mobile App | QA Staff | [Open Mobile Demo](https://qa-mobile-app.vercel.app/) |
| Web Admin Dashboard | Administrator | [Open Admin Demo](https://qa-mobile-web.vercel.app/) |

=======
The system consists of a Flutter application for Staff Warehouse, a React-based Admin Dashboard, an Express API, PostgreSQL, and private object storage.

> **Project status:** Active prototype/demo development. The system is not yet production-ready.

## Live Demo

| Application | User | Demo |
|---|---|---|
| Staff Warehouse Mobile App | Staff Warehouse | [Open Mobile Demo](https://qa-mobile-app.vercel.app/) |
| Web Admin Dashboard | Administrator | [Open Admin Demo](https://qa-mobile-web.vercel.app/) |

>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
Demo credentials are displayed on each application's login page.

> The deployments are intended for demonstration and testing. Authentication, account management, security hardening, and several production requirements are still under development.

## System Overview

QA Mobile Apps supports two main actors:

<<<<<<< HEAD
### QA Staff

QA Staff use the Flutter application to:
=======
### Staff Warehouse

Staff Warehouse use the Flutter application to:
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394

- View available QC Material and QC Pekerjaan templates.
- Fill numeric, boolean, choice, and text checklist items.
- Add notes and multiple evidence photos to checklist items.
- Save inspections as drafts.
- Restore and continue previously saved drafts.
- Submit completed inspection reports.
- View report history and report details.
- Monitor inspection summaries through the dashboard.
- Manage basic profile information.

<<<<<<< HEAD
QA Staff record inspection data but do not determine the final pass or fail result.
=======
Staff Warehouse record inspection data but do not determine the final pass or fail result.
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394

### Administrator

Administrators use the React Web Dashboard to:

- Monitor Quality Control activity.
- Manage QC Material and QC Pekerjaan templates.
<<<<<<< HEAD
- Review reports submitted by QA Staff.
=======
- Review reports submitted by Staff Warehouse.
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
- Inspect checklist answers, notes, and evidence photos.
- Approve or reject inspection reports.
- Determine the final inspection result.
- Filter reports by location, QC type, status, and standard result.
- View report statistics and dashboard summaries.

<<<<<<< HEAD
## Arsitektur dan aliran data

```mermaid
flowchart LR
    Mobile["Flutter QA Staff App"]
=======
## Architecture

```mermaid
flowchart LR
    Mobile["Flutter Staff Warehouse App"]
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
    Admin["React Web Admin"]
    API["Express REST API"]
    Database["Supabase PostgreSQL"]
    Storage["Private Supabase Storage"]
    JSON["JSON Local Fallback"]

    Mobile --> API
    Admin --> API
    API --> Database
    API --> Storage
    API -. Local development .-> JSON
```

The mobile and web applications must not access PostgreSQL tables or private storage credentials directly. Database and object-storage credentials are only configured in the Express backend environment.

## Technology Stack

| Layer | Technology |
|---|---|
<<<<<<< HEAD
| QA Staff Application | Flutter / Dart |
=======
| Staff Warehouse Application | Flutter / Dart |
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
| Admin Dashboard | React / TypeScript |
| Backend API | Node.js / Express |
| Database | Supabase PostgreSQL |
| Evidence Storage | Private Supabase Storage |
| Local Data Fallback | JSON |
| Frontend Deployment | Vercel |
| Version Control | Git / GitHub |

## Repository Structure

```text
QA-APPS-MOBILE/
├── apps/
<<<<<<< HEAD
│   ├── mobile/          # Flutter application for QA Staff
=======
│   ├── mobile/          # Flutter application for Staff Warehouse
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
│   └── web/             # React Admin Dashboard
├── mock-api/            # Canonical Express API
├── docs/                # Project and integration documentation
└── README.md
```

The deprecated backend previously located at `apps/mobile/mock-api` must not be used. The canonical backend is located at the repository root in `mock-api`.

## Main Workflows

### QC Material

```text
Admin creates a template
        ↓
<<<<<<< HEAD
QA Staff selects the material
        ↓
QA Staff fills checklist items and evidence
=======
Staff Warehouse selects the material
        ↓
Staff Warehouse fills checklist items and evidence
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
        ↓
Report is saved as Draft or Submitted
        ↓
Admin reviews the submitted report
        ↓
Admin approves or rejects the report
```

### QC Pekerjaan

```text
Admin creates a work template
        ↓
<<<<<<< HEAD
QA Staff selects the work inspection
        ↓
QA Staff fills checklist items and evidence
=======
Staff Warehouse selects the work inspection
        ↓
Staff Warehouse fills checklist items and evidence
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
        ↓
Report is saved as Draft or Submitted
        ↓
Admin reviews the submitted report
        ↓
Admin determines the final result
```

## Evidence Photo Management

Evidence photos can be attached to individual checklist items.

The current implementation supports:

- Camera and gallery selection.
- Multiple photos per checklist item.
- Draft photo persistence.
- Upload retry handling.
- Canonical object-path persistence.
- Private storage through the backend.
- Evidence display in report details.
- Removal of newly selected or restored draft photos.

Stored reports persist canonical object paths instead of temporary signed URLs.

## Local Development

### Prerequisites

Install the following tools:

- Node.js and npm
- Flutter SDK
- Android SDK for Android development
- A supported web browser
- Supabase project access when using PostgreSQL and Storage

### Backend API

```powershell
<<<<<<< HEAD
Copy-Item .env.example .env
npm.cmd ci
npm.cmd start
```

Backend lokal berjalan pada `http://localhost:3002` secara default.

### Admin Web - `web`

```powershell
Copy-Item .env.example .env.local
npm.cmd ci
npm.cmd run dev
```

Atur `VITE_API_BASE_URL=http://localhost:3002` di environment lokal. Vite
berjalan pada `http://localhost:5173` secara default.

### Mobile - `feat/mobile-qc-photo-integration`

```powershell
flutter pub get
dart tool/pre_build.dart
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3002
```

## Dokumentasi lengkap

**[docs/HANDOVER.md](docs/HANDOVER.md)** adalah sumber utama untuk setup,
testing, deployment, arsitektur, database dan Storage, aturan bisnis, known
issues, technical debt, serta panduan handover.

README ini hanya orientasi awal. Untuk informasi bertanda *perlu dikonfirmasi*
dan batas antara fakta repository dengan rekomendasi operasional, selalu rujuk
ke dokumen handover tersebut.
=======
cd mock-api
npm.cmd install
npm.cmd start
```

The canonical backend runs on:

```text
http://localhost:3002
```

### Web Admin

```powershell
cd apps/web
npm.cmd install
npm.cmd run dev
```

### Flutter Application

```powershell
cd apps/mobile
flutter pub get
flutter run
```

To run the Flutter application in Chrome:

```powershell
flutter run -d chrome
```

## API Access

The API base URL depends on the target platform:

| Platform | Backend URL |
|---|---|
| Flutter Web / Desktop | `http://localhost:3002` |
| Android Emulator | `http://10.0.2.2:3002` |
| Deployed Demo | Configured deployment API URL |

## Environment Configuration

Create the required environment files from the provided examples.

Do not commit:

- Database passwords.
- Supabase service-role keys.
- Storage credentials.
- Access tokens.
- Production secrets.

All database and private storage operations must go through the Express API.

## Current Development Status

Completed or integrated:

- Canonical Express API foundation.
- PostgreSQL schema and repair migrations.
- JSON fallback for local development.
- QC Material and QC Pekerjaan template integration.
- Mobile draft persistence.
- Checklist answer restoration.
- Multiple evidence photos per checklist item.
- Private evidence upload integration.
- Mobile report details.
- Admin report review and approval foundation.
- Flutter and React demo deployments.

Currently being stabilized:

- Mobile report submission timeout handling.
- Duplicate submission prevention.
- End-to-end report synchronization.
- Admin template editing consistency.
- Authentication and account management.
- Production environment configuration.
- Final mobile, web, and backend regression testing.

## Production Readiness

The current deployment is a prototype and still requires:

- Production-grade authentication.
- Role-based authorization.
- Secure account and session management.
- Password recovery.
- Request rate limiting.
- Monitoring and centralized logging.
- Backup and recovery procedures.
- Final security review.
- Full end-to-end and device testing.
- Deployment and operational documentation.

## Documentation

Project documentation is available in the [`docs`](docs/) directory.

Start with the [documentation index](docs/README.md) for architecture, database, storage, integration, and workflow references.

## Project Purpose

This project was developed as an internship project to demonstrate an integrated Quality Assurance workflow across mobile, web, backend, database, and private evidence storage systems.

## License

This repository is currently intended for internal development, demonstration, and evaluation.
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
