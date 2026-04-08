from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
from backend.api.routers import timetable_view
from contextlib import asynccontextmanager
from backend.database.session import engine, Base, SessionLocal
from backend.database.models.sync_revision import MasterSyncRevisionModel
from backend.api.routers.timetable_router import router as timetable_router
from backend.api.routers.session_router import router as session_router
from backend.api.routers.admin import (
    branch_router,
    classroom_router,
    teacher_router,
    subject_router,
    student_router,
    group_router,
    group_student_router,
    enrollment_router,
    teacher_availability_router,
    slot_router
)
from sqladmin import Admin
from backend.admin import (
    BranchAdmin,
    ClassroomAdmin,
    TeacherAdmin,
    SubjectAdmin,
    StudentAdmin,
    GroupAdmin,
    EnrollmentAdmin,
    SlotAdmin
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    import logging
    from backend.database.config import DATABASE_URL
    from backend.database.session import init_sqlite_database
    
    # Initialize WAL mode and connection settings safely
    init_sqlite_database()
    
    logging.info(f"Lifespan startup: Initializing database at {DATABASE_URL}")
    Base.metadata.create_all(bind=engine)
    logging.info("Database schema created/verified.")
    
    # Initialize Master Sync Revision if not exists
    db = SessionLocal()
    try:
        # --- ZERO-CONFIGURATION BOOTSTRAP ---
        logging.info("Running bootstrap service...")
        from backend.api.services.bootstrap_service import bootstrap_central_database
        bootstrap_central_database(db)
        logging.info("Bootstrap complete.")

        # Sync Revision
        rev = db.query(MasterSyncRevisionModel).filter_by(id=1).first()
        if not rev:
            from datetime import datetime
            logging.info("Initializing Master Sync Revision...")
            db.add(MasterSyncRevisionModel(id=1, last_updated_at=datetime.utcnow()))
            db.commit()
    except Exception as e:
        logging.error(f"Error during lifespan startup: {e}")
    finally:
        db.close()
        
    logging.info("Lifespan startup finished. App is ready.")
    yield
    # Shutdown (nothing for now)


app = FastAPI(lifespan=lifespan)

# ── Secret key middleware — blocks browser access to API ──
APP_SECRET_KEY = "unischeduler-desktop-client-2026"

class AppKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        # Allow admin panel, docs, export downloads, and OPTIONS preflight requests through
        if (path.startswith("/admin") or path in ("/docs", "/redoc", "/openapi.json") 
            or "/export" in path or request.method == "OPTIONS"):
            return await call_next(request)
        # Check for the app key header
        app_key = request.headers.get("x-app-key")
        if app_key != APP_SECRET_KEY:
            return JSONResponse(
                status_code=403,
                content={"detail": "Access denied. This API is only accessible from the UniScheduler application."},
            )
        return await call_next(request)

app.add_middleware(AppKeyMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(timetable_router)
app.include_router(session_router)
app.include_router(branch_router.router)
app.include_router(classroom_router.router)
app.include_router(teacher_router.router)
app.include_router(subject_router.router)
app.include_router(student_router.router)
app.include_router(group_router.router)
app.include_router(group_student_router.router)
app.include_router(enrollment_router.router)
app.include_router(teacher_availability_router.router)
app.include_router(slot_router.router)


app.include_router(timetable_view.router, prefix="/timetable")

@app.get("/")
def root():
    return {"message": "Scheduler Backend Running 🚀"}

admin = Admin(app, engine)

admin.add_view(BranchAdmin)
admin.add_view(ClassroomAdmin)
admin.add_view(TeacherAdmin)
admin.add_view(SubjectAdmin)
admin.add_view(StudentAdmin)
admin.add_view(GroupAdmin)
admin.add_view(EnrollmentAdmin)
admin.add_view(SlotAdmin)
