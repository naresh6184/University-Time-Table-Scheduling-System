from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List

from backend.database.session import get_db
from backend.api.schemas.student_schema import StudentCreate, StudentResponse, StudentUpdate
from backend.api.services.student_service import (
    create_student,
    get_all_students,
    search_students,
    update_student
)
from backend.api.services.student_import_service import preview_student_import, commit_student_import

router = APIRouter(
    prefix="/admin/students",
    tags=["Admin - Student"]
)

@router.post("/", response_model=StudentResponse)
def create(student: StudentCreate, db: Session = Depends(get_db)):
    return create_student(db, student)

@router.get("/", response_model=List[StudentResponse])
def read_all(db: Session = Depends(get_db)):
    return get_all_students(db)

@router.get("/search", response_model=List[StudentResponse])
def search(q: str = Query(...), db: Session = Depends(get_db)):
    return search_students(db, q)

@router.put("/{student_id}", response_model=StudentResponse)
def update(student_id: str, student: StudentUpdate, db: Session = Depends(get_db)):
    return update_student(db, student_id, student)

@router.post("/bulk-upload/preview")
async def bulk_upload_preview(file: UploadFile = File(...), db: Session = Depends(get_db)):
    content = await file.read()
    return preview_student_import(db, content)

@router.post("/bulk-upload/confirm")
def bulk_upload_confirm(students: List[dict], db: Session = Depends(get_db)):
    count = commit_student_import(db, students)
    return {"message": f"Successfully imported {count} students"}
