from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List

from backend.database.session import get_db
from backend.api.schemas.student_schema import StudentCreate, StudentResponse, StudentUpdate, StudentBulkDelete, StudentBulkUpdate
from backend.api.services.student_service import (
    create_student,
    get_all_students,
    search_students,
    update_student,
    delete_student,
    bulk_delete_students,
    bulk_update_students
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

@router.delete("/{student_id}")
def delete(student_id: str, db: Session = Depends(get_db)):
    return delete_student(db, student_id)

@router.post("/bulk-delete")
def bulk_delete(data: StudentBulkDelete, db: Session = Depends(get_db)):
    count = bulk_delete_students(db, data.student_ids)
    return {"message": f"Successfully deleted {count} students"}

@router.post("/bulk-update")
def bulk_update(data: StudentBulkUpdate, db: Session = Depends(get_db)):
    count = bulk_update_students(db, data.student_ids, data.branch_id, data.batch, data.program)
    return {"message": f"Successfully updated {count} students"}

@router.post("/bulk-upload/preview")
async def bulk_upload_preview(file: UploadFile = File(...), db: Session = Depends(get_db)):
    content = await file.read()
    return preview_student_import(db, content)

@router.post("/bulk-upload/confirm")
def bulk_upload_confirm(students: List[dict], db: Session = Depends(get_db)):
    count = commit_student_import(db, students)
    return {"message": f"Successfully imported {count} students"}
