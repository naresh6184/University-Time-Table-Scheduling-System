from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from backend.database.session import get_db
from backend.api.schemas.classroom_schema import ClassroomCreate, ClassroomResponse, ClassroomUpdate
from backend.api.services.classroom_service import (
    create_classroom,
    get_all_classrooms,
    delete_classroom,
    update_classroom
)

router = APIRouter(
    prefix="/admin/classrooms",
    tags=["Admin - Classroom"]
)


@router.post("/", response_model=ClassroomResponse)
def create(classroom: ClassroomCreate, db: Session = Depends(get_db)):
    return create_classroom(db, classroom)


@router.get("/", response_model=list[ClassroomResponse])
def read_all(db: Session = Depends(get_db)):
    return get_all_classrooms(db)


@router.delete("/{room_id}")
def remove(room_id: int, db: Session = Depends(get_db)):
    delete_classroom(db, room_id)
    return {"message": "Classroom deleted"}


@router.put("/{room_id}", response_model=ClassroomResponse)
def update(room_id: int, classroom: ClassroomUpdate, db: Session = Depends(get_db)):
    return update_classroom(db, room_id, classroom)
