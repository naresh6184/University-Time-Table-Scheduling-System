from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from backend.database.session import get_db
from backend.api.schemas.group_schema import GroupCreate, GroupResponse, GroupUpdate
from backend.api.services.group_service import (
    create_group,
    get_all_groups,
    get_group_students,
    update_group,
    delete_group
)
from backend.api.schemas.student_schema import StudentResponse

router = APIRouter(
    prefix="/admin/groups",
    tags=["Admin - Group"]
)


@router.post("/", response_model=GroupResponse)
def create(group: GroupCreate, db: Session = Depends(get_db)):
    return create_group(db, group)


@router.get("/", response_model=list[GroupResponse])
def read_all(db: Session = Depends(get_db)):
    return get_all_groups(db)


@router.get("/{group_id}/students", response_model=list[StudentResponse])
def read_students(group_id: int, db: Session = Depends(get_db)):
    return get_group_students(db, group_id)


@router.delete("/{group_id}")
def remove(group_id: int, db: Session = Depends(get_db)):
    delete_group(db, group_id)
    return {"message": "Group deleted"}


@router.put("/{group_id}", response_model=GroupResponse)
def update(group_id: int, group: GroupUpdate, db: Session = Depends(get_db)):
    return update_group(db, group_id, group)
