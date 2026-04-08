from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from backend.database.session import get_db
from backend.api.schemas.teacher_schema import TeacherCreate, TeacherResponse, TeacherUpdate
from backend.api.services.teacher_service import (
    create_teacher,
    get_all_teachers,
    delete_teacher,
    update_teacher
)

router = APIRouter(
    prefix="/admin/teachers",
    tags=["Admin - Teacher"]
)

@router.post("/", response_model=TeacherResponse)
def create(teacher: TeacherCreate, db: Session = Depends(get_db)):
    return create_teacher(db, teacher)

@router.get("/", response_model=list[TeacherResponse])
def read_all(db: Session = Depends(get_db)):
    return get_all_teachers(db)

@router.delete("/{teacher_id}")
def remove(teacher_id: int, db: Session = Depends(get_db)):
    delete_teacher(db, teacher_id)
    return {"message": "Teacher deleted"}

@router.put("/{teacher_id}", response_model=TeacherResponse)
def update(teacher_id: int, teacher: TeacherUpdate, db: Session = Depends(get_db)):
    return update_teacher(db, teacher_id, teacher)
