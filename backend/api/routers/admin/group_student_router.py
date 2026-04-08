from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from backend.database.session import get_db
from backend.api.schemas.group_student_schema import GroupStudentCreate, BulkAddRequest, BulkRemoveRequest
from backend.api.services.group_student_service import (
    add_student_to_group,
    bulk_add_by_branch,
    bulk_add_by_group,
    bulk_add_by_ids,
    delete_group_student,
    bulk_remove_by_ids
)

router = APIRouter(
    prefix="/admin/group-students",
    tags=["Admin - Group Student"]
)

@router.post("/")
def add(data: GroupStudentCreate, db: Session = Depends(get_db)):
    return add_student_to_group(db, data)

@router.post("/bulk-add")
def bulk_add(request: BulkAddRequest, branch_id: int = Query(None), source_group_id: int = Query(None), db: Session = Depends(get_db)):
    if request.student_ids:
        bulk_add_by_ids(db, request.target_group_id, request.student_ids)
    elif branch_id:
        bulk_add_by_branch(db, request.target_group_id, branch_id)
    elif source_group_id:
        bulk_add_by_group(db, request.target_group_id, source_group_id)
    return {"message": "Students added successfully"}

@router.post("/bulk-remove")
def bulk_remove(request: BulkRemoveRequest, db: Session = Depends(get_db)):
    if request.student_ids:
        bulk_remove_by_ids(db, request.target_group_id, request.student_ids)
    return {"message": "Students removed successfully"}

@router.delete("/{group_id}/{student_id}")
def remove_from_group(group_id: int, student_id: str, db: Session = Depends(get_db)):
    delete_group_student(db, group_id, student_id)
    return {"message": "Student removed from group"}
