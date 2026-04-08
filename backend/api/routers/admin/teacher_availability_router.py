from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from backend.database.session import get_db
from backend.api.schemas.teacher_availability_schema import TeacherAvailabilityCreate, BulkTeacherAvailabilityRequest
from backend.api.services.teacher_availability_service import (
    add_teacher_availability, 
    get_teacher_availability,
    bulk_update_teacher_availability
)

router = APIRouter(
    prefix="/admin/teacher-availability",
    tags=["Admin - Teacher Availability"]
)

@router.get("/{teacher_id}")
def get_availability(teacher_id: int, session_id: int = -1, db: Session = Depends(get_db)):
    return get_teacher_availability(db, teacher_id, session_id)

@router.post("/{teacher_id}/bulk")
def bulk_update(teacher_id: int, data: BulkTeacherAvailabilityRequest, session_id: int = -1, db: Session = Depends(get_db)):
    return bulk_update_teacher_availability(db, teacher_id, data, session_id, data.all_slots)

@router.post("/")
def add(data: TeacherAvailabilityCreate, db: Session = Depends(get_db)):
    return add_teacher_availability(db, data)