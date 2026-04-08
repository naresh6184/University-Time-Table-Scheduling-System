from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from backend.database.session import get_db
from backend.api.schemas.subject_schema import SubjectCreate, SubjectResponse, SubjectUpdate
from backend.api.services.subject_service import (
    create_subject,
    get_all_subjects,
    delete_subject,
    update_subject
)

router = APIRouter(
    prefix="/admin/subjects",
    tags=["Admin - Subject"]
)

@router.post("/", response_model=SubjectResponse)
def create(subject: SubjectCreate, db: Session = Depends(get_db)):
    return create_subject(db, subject)

@router.get("/", response_model=list[SubjectResponse])
def read_all(db: Session = Depends(get_db)):
    return get_all_subjects(db)

@router.delete("/{subject_id}")
def remove(subject_id: int, db: Session = Depends(get_db)):
    delete_subject(db, subject_id)
    return {"message": "Subject deleted"}

@router.put("/{subject_id}", response_model=SubjectResponse)
def update(subject_id: int, subject: SubjectUpdate, db: Session = Depends(get_db)):
    return update_subject(db, subject_id, subject)
