# 🗓️ UniScheduler — University Timetable Scheduling System

A full-stack, AI-powered university timetable generator. UniScheduler uses a **multi-objective NSGA-II genetic algorithm** to automatically produce conflict-free, optimized timetables — packaged as a polished desktop application with a Flutter frontend and a FastAPI backend.

---

## 📥 Downloads

**[Download the Latest Windows Installer](https://github.com/naresh6184/University-Time-Table-Scheduling-System/releases)**

---

## ✨ Features

- **Automated Timetable Generation** — NSGA-II (Non-dominated Sorting Genetic Algorithm II) optimizes schedules across multiple competing objectives simultaneously.
- **Hard Constraint Enforcement** — Zero tolerance for teacher double-booking, room conflicts, group overlaps, lunch-break crossings, and day-boundary violations.
- **Soft Objective Optimization** — Minimizes student free gaps, teacher idle time, room waste, teacher dissatisfaction, and uneven subject distribution across days.
- **Multi-Start Engine** — Runs up to 5 independent NSGA-II attempts to maximize the chance of finding a fully feasible (zero-conflict) solution.
- **Real-Time Generation Feed** — Live progress updates stream from the backend to the frontend during scheduling, including per-generation violation counts and conflict breakdowns.
- **Conflict Reporting** — Detailed per-instance conflict logs (teacher overlap, room conflict, student overlap, etc.) are persisted alongside each timetable version.
- **Timetable Versioning** — Multiple generated timetable versions are stored per academic session, allowing comparison and rollback.
- **Admin Data Center** — Full CRUD management for branches, classrooms, teachers, subjects, students, groups, enrollments, and time slots.
- **Teacher Availability & Preferences** — Teachers can be assigned available slots and ranked slot preferences, which the optimizer respects.
- **Bulk Student Import** — Import students from files directly into groups.
- **Excel Export** — Export finalized timetables to `.xlsx` for sharing and printing.
- **Session Management** — Multiple independent scheduling sessions (e.g., one per semester) with copy/sync support.
- **Cross-Platform Desktop App** — Flutter frontend targets Windows, macOS, and Linux.
- **Zero-Config Bootstrap** — The backend automatically initializes the SQLite database and default data on first run.
- **Bundleable as a Windows Installer** — Includes PyInstaller and Inno Setup configurations for standalone deployment.

---

## 🏗️ Architecture

```
University-Time-Table-Scheduling-System/
├── backend/
│   ├── api/
│   │   ├── main.py                  # FastAPI app, middleware, router registration
│   │   ├── routers/                 # REST endpoints (admin CRUD, timetable, sessions, views)
│   │   ├── schemas/                 # Pydantic request/response models
│   │   ├── services/                # Business logic (timetable service, session copy, Excel export…)
│   │   └── utils/                   # Excel exporter, timetable utilities
│   ├── bridge/
│   │   ├── data_loader.py           # Loads and prepares DB data for the scheduler engine
│   │   └── runner.py                # Orchestrates multi-start NSGA-II runs, progress tracking
│   ├── database/
│   │   ├── config.py                # DB URL, logging setup, PyInstaller-aware path resolution
│   │   ├── session.py               # SQLAlchemy engine & session factory
│   │   └── models/                  # ORM models (Branch, Classroom, Teacher, Subject, Student,
│   │                                #   Group, Enrollment, Slot, TimetableEntry, TimetableVersion,
│   │                                #   TimetableConflict, Session, SessionEntities…)
│   ├── scheduler_engine/
│   │   ├── entities.py              # Dataclasses used by the GA (Teacher, Group, Classroom…)
│   │   ├── initialization.py        # Random feasible chromosome generator
│   │   ├── constraints.py           # Hard constraint evaluator with weighted violation scoring
│   │   ├── objectives.py            # 5 soft objectives: student gap, teacher gap, room waste,
│   │   │                            #   teacher dissatisfaction, subject distribution
│   │   ├── nsga2.py                 # Full NSGA-II: fast non-dominated sort, crowding distance,
│   │   │                            #   tournament selection, crossover, mutation, repair operator
│   │   └── generator.py             # Entry point called by the bridge runner
│   └── admin.py                     # SQLAdmin views for the /admin panel
├── frontend/
│   └── lib/
│       ├── main.dart
│       └── src/
│           ├── features/            # Dashboard, Data Center, Enrollment, Sessions,
│           │                        #   Timetable Generator, Timetable View, Settings, Help…
│           ├── models/              # Dart data models (academic entities, grid, session, timetable)
│           ├── services/
│           │   ├── api_service.dart # HTTP client (Dio) wrapping all backend REST calls
│           │   └── server_manager.dart # Manages the embedded backend process lifecycle
│           ├── routing/             # go_router navigation shell
│           └── theme/               # FlexColorScheme-based theming with dark/light support
├── run_server.py                    # Uvicorn entry point (also used by PyInstaller bundle)
├── UniScheduler_Server.spec         # PyInstaller spec for backend executable
└── unischeduler_installer.iss       # Inno Setup script for Windows installer
```

---

## 🧠 Scheduling Algorithm

The core engine is a **custom NSGA-II** (Non-dominated Sorting Genetic Algorithm II) implementation.

### Chromosome Representation
Each individual is a list of **genes**, where every gene is a 4-tuple:
```
(enrollment_id, room_id, start_slot, duration)
```

### Hard Constraints (violation = disqualifying)
| Constraint | Penalty Weight |
|---|---|
| Lunch break crossing (P4→P5) | 100,000 |
| Same-day duplicate for same enrollment | 1,000 |
| Missing / unplaced class | 1,000 |
| Day boundary crossing | 500 |
| Teacher / Room / Group double-booking | 10 each |
| Teacher unavailability | 1 |
| Room capacity exceeded | 1 |
| Room type mismatch (theory vs lab) | 1 |

### Soft Objectives (multi-objective Pareto optimization)
1. **Student Gap** — minimize idle periods between classes for each group per day
2. **Teacher Gap** — minimize idle periods between classes for each teacher per day
3. **Room Waste** — minimize the mismatch between room capacity and actual group size
4. **Teacher Dissatisfaction** — minimize scheduling outside preferred slots and uneven day loads
5. **Subject Distribution** — minimize same-day repetition of the same subject for a group

### Genetic Operators
- **Repair Operator** — A constraint-aware heuristic that fixes infeasible genes in three passes (ideal → relax same-day → emergency fallback), prioritizing most-constrained teachers first.
- **Crossover** — Two-point crossover between parent chromosomes.
- **Mutation** — Per-gene slot/room perturbation (rate 0.15 rising to 0.30 once a feasible solution is found).
- **Selection** — Binary tournament selection using Pareto rank and crowding distance.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Backend Language** | Python 3.10+ |
| **API Framework** | FastAPI + Uvicorn |
| **ORM / Database** | SQLAlchemy + SQLite |
| **Admin Panel** | SQLAdmin |
| **Scheduling Engine** | Custom NSGA-II (pure Python) |
| **Excel Export** | openpyxl (via `excel_exporter.py`) |
| **Frontend Language** | Dart / Flutter (stable channel) |
| **State Management** | Riverpod |
| **HTTP Client** | Dio |
| **Routing** | go_router |
| **Charts** | fl_chart |
| **Theming** | FlexColorScheme + Google Fonts |
| **Packaging** | PyInstaller + Inno Setup (Windows) |

---

## 🚀 Getting Started

### Prerequisites

- **Python** 3.10 or higher
- **Flutter SDK** (stable channel, 3.x)
- Git

---

### 1. Clone the Repository

```bash
git clone https://github.com/naresh6184/University-Time-Table-Scheduling-System.git
cd University-Time-Table-Scheduling-System
```

---

### 2. Backend Setup

**a. Create and activate a virtual environment**

```bash
python -m venv venv

# macOS / Linux
source venv/bin/activate

# Windows
venv\Scripts\activate
```

**b. Install dependencies**

```bash
pip install -r requirements.txt
```

**c. Configure environment variables**

```bash
cp backend/.env.example backend/.env
```

The default `.env` uses a local SQLite file (`app_db.sqlite`) — no additional database setup is required.

**d. Start the backend server**

```bash
python run_server.py
```

The server starts at **`http://127.0.0.1:8000`**.

- API docs: `http://127.0.0.1:8000/docs`
- Admin panel: `http://127.0.0.1:8000/admin`

---

### 3. Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

To target a specific platform:

```bash
flutter run -d windows   # Windows desktop
flutter run -d macos     # macOS desktop
flutter run -d linux     # Linux desktop
```

---

## 📋 Usage Workflow

1. **Set Up Data** — In the *Data Center*, add branches, classrooms (with capacity and type), teachers (with available slots and preferences), subjects, students, and groups.
2. **Enroll** — In the *Enrollment* screen, assign teachers and groups to subjects for the session.
3. **Configure Slots** — In *Slot Config*, define the weekly time slot grid (days × periods).
4. **Generate** — In the *Generator Hub*, launch the NSGA-II engine. Watch real-time progress and conflict counts as generations evolve.
5. **Review** — In the *Timetable View*, inspect the resulting schedule in a grid layout. Conflict details are highlighted.
6. **Export** — Download the finalized timetable as an Excel file.

---

## 📦 Building a Standalone Windows Installer

The project includes `UniScheduler_Server.spec` (PyInstaller) and `unischeduler_installer.iss` (Inno Setup) to package everything into a single Windows installer.

### Step 1 — Prepare the backend `.env`

The `.spec` file bundles `backend/.env` into the executable. This file is not committed to the repo, so create it first:

```bash
cp backend/.env.example backend/.env
```

### Step 2 — Build the backend executable

```bash
pyinstaller UniScheduler_Server.spec
```

This produces `dist/UniScheduler_Server/` — a self-contained folder with the server binary and all dependencies. The server window will be **visible** (`console=True`) so startup errors are never silently swallowed.

> **Note:** The spec explicitly lists all admin routers, database models, scheduler engine modules, and FastAPI runtime dependencies (`anyio`, `email_validator`, `multipart`, `sqlalchemy.dialects.sqlite`) as `hiddenimports`. These are required because PyInstaller cannot auto-discover dynamically loaded modules.

### Step 3 — Build the Flutter Windows app

```bash
cd frontend
flutter build windows
```

### Step 4 — Compile the installer

Open `unischeduler_installer.iss` in **Inno Setup Compiler** and click *Build*. The installer `.exe` will be placed in an `installer_output/` folder next to the script (works on any machine — no hardcoded paths).

The installer bundles:
- `frontend\build\windows\x64\runner\Release\*` → `{app}\` (Flutter app)
- `dist\UniScheduler_Server\*` → `{app}\server\` (Python backend)

All shortcuts and the post-install launch use `WorkingDir: "{app}"` so relative paths resolve correctly at runtime.

---

## 🔒 API Security

All API endpoints (except `/admin`, `/docs`, and export routes) require the header:

```
x-app-key: unischeduler-desktop-client-2026
```

This prevents direct browser access to the API and ensures only the desktop client can interact with the backend.

---

## 👤 Author

**Naresh Kumar**  
📧 [nareshjangir6184@gmail.com](mailto:nareshjangir6184@gmail.com)

---

## 📄 License

## 🙏 Acknowledgements

- [NSGA-II](https://ieeexplore.ieee.org/document/996017) — Deb et al., 2002
- [FastAPI](https://fastapi.tiangolo.com/)
- [Flutter](https://flutter.dev/)
- [SQLAdmin](https://aminalaee.dev/sqladmin/)
