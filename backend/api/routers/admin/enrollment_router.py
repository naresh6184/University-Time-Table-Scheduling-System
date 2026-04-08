from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from backend.database.session import get_db
from backend.api.schemas.enrollment_schema import EnrollmentCreate, EnrollmentResponse, EnrollmentUpdate
from backend.api.services.enrollment_service import (
    create_enrollment,
    get_all_enrollments,
    update_enrollment,
    delete_enrollment
)

router = APIRouter(
    prefix="/admin/enrollments",
    tags=["Admin - Enrollment"]
)


@router.post("/", response_model=EnrollmentResponse)
def create(data: EnrollmentCreate, db: Session = Depends(get_db)):
    return create_enrollment(db, data)


@router.get("/", response_model=list[EnrollmentResponse])
def read_all(session_id: int, db: Session = Depends(get_db)):
    return get_all_enrollments(db, session_id)


@router.put("/{enrollment_id}", response_model=EnrollmentResponse)
def update(enrollment_id: int, data: EnrollmentUpdate, db: Session = Depends(get_db)):
    return update_enrollment(db, enrollment_id, data)


@router.delete("/{enrollment_id}")
def delete(enrollment_id: int, db: Session = Depends(get_db)):
    delete_enrollment(db, enrollment_id)
    return {"message": "Enrollment deleted successfully"}