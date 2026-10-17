# 🛡️ ShieldWatch — Crime Reporting & Community Safety System

A modern, full-stack Web Application built entirely in **Swift** using **Vapor 4**, **Fluent ORM (SQLite)**, and **Leaf Templating Engine** with **Tailwind CSS**. Designed as a college iOS & Server-Side Swift Lab mini-project following strict **Model-View-Controller (MVC)** architectural standards.

---

## 🚀 Key Features

1. **Crime Reporting Module** (`/report`)
   - Secure web form allowing users to submit incident reports.
   - Form fields: Title, Location (with quick autocomplete chips), Detailed Description, and Affirmation.
   - **Multipart/Form-Data Media Uploads**: Securely uploads and stores photos (JPG, PNG, WEBP) or videos (MP4, MOV) in `Public/uploads/` with UUID-based collision resistance.
   - Automatic client-side preview for attached media before submission.

2. **Case Tracking Dashboard** (`/dashboard`)
   - Real-time case tracking table with dynamic status badges:
     - 🟡 **Pending** (Awaiting officer review)
     - 🔵 **Under Investigation** (Active inquiries underway)
     - 🟢 **Resolved** (Case verified and closed)
   - Real-time status update control: allows officers to transition case states directly from the UI.
   - Filter cases by status tabs (`All`, `Pending`, `Under Investigation`, `Resolved`) and search across titles, locations, and descriptions.
   - Embedded evidence viewer for photos and video clips.

3. **Community Safety Concerns Feed** (`/concerns`)
   - Public community hazard bulletin to report broken streetlights, unlit pathways, or suspicious activities.
   - Severity categorization: **Low**, **Medium**, **High** with color-coded alerts.
   - Option for anonymous or credited community reporting.

4. **RESTful JSON API Endpoints** (`/api/reports` and `/api/concerns`)
   - Full JSON endpoints to easily interface with iOS apps (SwiftUI / UIKit) or external mobile clients.

---

## 🛠️ Tech Stack & Architecture

- **Backend Language**: Swift 5.9+ / Swift 6
- **Server Framework**: [Vapor 4](https://vapor.codes/)
- **Database ORM**: Fluent SQLite Driver (zero external database configuration required)
- **View Engine**: [Leaf 4](https://docs.vapor.codes/leaf/overview/)
- **Styling**: Tailwind CSS (loaded via CDN)
- **Architecture**: MVC (Model-View-Controller)

```
CrimeReportingSystem/
├── Package.swift                  # SPM dependencies (Vapor, Fluent, SQLite, Leaf)
├── Sources/
│   ├── Run/
│   │   └── main.swift             # Application bootstrapping & server lifecycle
│   └── App/
│       ├── Models/                # Fluent ORM Database Entities (Models)
│       │   ├── CrimeReport.swift
│       │   └── SafetyConcern.swift
│       ├── Migrations/            # Database Schema Migrations
│       │   ├── CreateCrimeReport.swift
│       │   ├── CreateSafetyConcern.swift
│       │   └── SeedInitialData.swift
│       ├── Controllers/           # Business Logic & Request Handlers (Controllers)
│       │   ├── CrimeReportController.swift
│       │   └── SafetyConcernController.swift
│       ├── configure.swift        # App services, SQLite setup, middleware, body size limits
│       └── routes.swift           # Route registry and controller binding
├── Resources/
│   └── Views/                     # HTML Leaf Templates (Views)
│       ├── base.leaf              # Master layout (Tailwind CDN, navbar, footer)
│       ├── index.leaf             # Home landing portal & metrics
│       ├── report.leaf            # Incident reporting form with file upload
│       ├── dashboard.leaf         # Real-time case tracking dashboard
│       └── concerns.leaf          # Public safety alerts feed
└── Public/
    └── uploads/                   # Local storage for user-submitted evidence media
```

---

## ⚡ Quick Start & Run Commands

### Prerequisites
- macOS (with Xcode 15+ / Command Line Tools) OR Linux (Ubuntu with Swift toolchain installed).
- Swift 5.9 or higher.

Verify your Swift version:
```bash
swift --version
```

### 1. Clone or Open the Project
```bash
cd CrimeReportingSystem
```

### 2. Build the Application
Resolve dependencies and compile all Swift targets:
```bash
swift build
```

### 3. Run Database Migrations
Create the SQLite database schema (`db.sqlite`) and seed initial demo data:
```bash
swift run Run migrate --auto-migrate
```
*(Alternatively, you can run `swift run Run migrate` and type `y` when prompted).*

### 4. Start the Vapor Web Server
```bash
swift run Run
```
By default, Vapor serves on:
👉 **`http://localhost:8080`** (or `http://127.0.0.1:8080`)

Open your web browser and navigate to:
- **Home Portal**: `http://localhost:8080/`
- **File a Report**: `http://localhost:8080/report`
- **Case Dashboard**: `http://localhost:8080/dashboard`
- **Safety Feed**: `http://localhost:8080/concerns`

---

## 🎓 Faculty Viva & Technical Walkthrough Guide

Here is a quick reference to explain the Swift & Vapor concepts used in this project to your college evaluators:

### 1. How does Vapor handle routing?
In `Sources/App/routes.swift`, we use `RouteCollection` structs (`CrimeReportController` and `SafetyConcernController`). Each controller defines its own `boot(routes: RoutesBuilder)` method. This keeps the codebase modular and follows the Single Responsibility Principle.

### 2. How does Fluent ORM map Swift structs to SQLite?
In `CrimeReport.swift`:
- `@ID(key: .id) var id: UUID?`: Marks `id` as the primary key.
- `@Field(key: "title") var title: String`: Maps Swift properties directly to SQLite columns.
- `@Enum(key: "status") var status: ReportStatus`: Enforces type-safe enums in the database (`Pending`, `Under Investigation`, `Resolved`).
- `@Timestamp(key: "created_at", on: .create)`: Automatically records creation timestamps without manual date handling.

### 3. How does the Multipart File Upload work?
- In `CrimeReportController.swift`, `CreateReportDTO` declares a `media: Vapor.File?` property.
- When a user submits an image or video, Vapor decodes the binary byte buffer (`media.data.readableBytes`).
- We sanitize the file extension, generate a unique `UUID` filename to avoid collisions and directory traversal attacks, and write the file non-blockingly to `Public/uploads/` using `req.application.fileio.writeFile(...)`.
- The relative path `/uploads/filename.ext` is saved in the database, and `FileMiddleware` configured in `configure.swift` serves it directly.

### 4. How does Leaf render dynamic HTML?
Leaf acts as the View layer in MVC. When `req.view.render("dashboard", context)` is called, Vapor serializes the Swift `DashboardViewContext` struct into Leaf variables:
- `#extend("base")`: Inherits header, navbar, and footer.
- `#for(report in reports)`: Loops through Swift database records.
- `#(report.status.rawValue)`: Injects model properties directly into HTML.

---

## 📡 REST API Reference (For iOS Mobile Client)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/reports` | Returns JSON array of all crime reports |
| `POST` | `/api/reports` | Create report via JSON or multipart/form-data |
| `GET` | `/api/reports/:id` | Retrieve single crime report details |
| `PATCH` | `/api/reports/:id/status` | Update case status (`Pending`, `Under Investigation`, `Resolved`) |
| `DELETE` | `/api/reports/:id` | Delete crime report record |
| `GET` | `/api/concerns` | Returns JSON array of safety concerns |
| `POST` | `/api/concerns` | Create community safety concern |
| `DELETE` | `/api/concerns/:id` | Delete safety concern |

