# University Timetable Scheduler

A comprehensive automated scheduling system designed for university environments. This project features a high-performance Python backend and a modern, cross-platform Flutter frontend.

## 🚀 Getting Started

### Prerequisites

- **Backend**: Python 3.10+
- **Frontend**: Flutter SDK (Stable channel)

---

### 🛠️ Backend Setup

1. **Configure Environment Variables**:
   In the `backend/` directory, copy the template environment file:
   ```bash
   cp backend/.env.example backend/.env
   ```
   By default, it is configured to use a local SQLite database (`app_db.sqlite`).

2. **Install Dependencies**:
   It is recommended to use a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install fastapi uvicorn sqlalchemy python-dotenv
   ```

3. **Run the Server**:
   ```bash
   python run_server.py
   ```
   The backend will start at `http://127.0.0.1:8000`.

---

### 📱 Frontend Setup

1. **Install Dependencies**:
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Run the Application**:
   ```bash
   flutter run
   ```

---

## 🏗️ Project Structure

- `backend/`: Python source code, scheduling algorithms, and API endpoints.
- `frontend/`: Flutter source code for the user interface.
- `run_server.py`: Main entry point for the backend server.
- `UniScheduler_Server.spec`: PyInstaller configuration for standalone builds.
- `unischeduler_installer.iss`: Inno Setup configuration for Windows installation.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details (if applicable).
