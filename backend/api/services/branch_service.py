from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from backend.database.models.branch import BranchModel


def create_branch(db: Session, branch_data):
    branch = BranchModel(**branch_data.model_dump())

    db.add(branch)
    db.commit()
    db.refresh(branch)

    return branch


def get_all_branches(db: Session):
    return db.query(BranchModel).all()


def get_branch(db: Session, branch_id: int):
    return db.query(BranchModel).filter(
        BranchModel.branch_id == branch_id
    ).first()


def delete_branch(db: Session, branch_id: int):
    branch = get_branch(db, branch_id)

    if branch:
        try:
            db.delete(branch)
            db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(
                status_code=409,
                detail="Cannot delete this branch because it still has students or groups assigned to it. Please remove or reassign them first."
            )

def update_branch(db: Session, branch_id: int, branch_data):
    branch = get_branch(db, branch_id)
    if branch:
        for key, value in branch_data.model_dump(exclude_unset=True).items():
            setattr(branch, key, value)
        db.commit()
        db.refresh(branch)
    return branch
