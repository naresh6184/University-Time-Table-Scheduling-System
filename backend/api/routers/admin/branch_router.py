from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from backend.database.session import get_db
from backend.api.schemas.branch_schema import BranchCreate, BranchResponse, BranchUpdate
from backend.api.services.branch_service import (
    create_branch,
    get_all_branches,
    get_branch,
    delete_branch,
    update_branch
)

router = APIRouter(
    prefix="/admin/branches",
    tags=["Admin Branch"]
)


@router.post("/", response_model=BranchResponse)
def create(branch: BranchCreate, db: Session = Depends(get_db)):
    return create_branch(db, branch)


@router.get("/", response_model=list[BranchResponse])
def list_branches(db: Session = Depends(get_db)):
    return get_all_branches(db)


@router.get("/{branch_id}", response_model=BranchResponse)
def read(branch_id: int, db: Session = Depends(get_db)):
    return get_branch(db, branch_id)


@router.delete("/{branch_id}")
def remove(branch_id: int, db: Session = Depends(get_db)):
    delete_branch(db, branch_id)
    return {"message": "Branch deleted"}


@router.put("/{branch_id}", response_model=BranchResponse)
def update(branch_id: int, branch: BranchUpdate, db: Session = Depends(get_db)):
    return update_branch(db, branch_id, branch)
