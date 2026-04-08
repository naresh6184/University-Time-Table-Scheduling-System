from sqlalchemy.orm import Session
from backend.database.models.group_student import GroupStudentModel


def add_student_to_group(db: Session, data):
    entry = GroupStudentModel(**data.model_dump())

    db.add(entry)
    db.commit()

    return entry

from backend.database.models.student import StudentModel

def bulk_add_by_branch(db: Session, target_group_id: int, branch_id: int):
    students = db.query(StudentModel).filter(StudentModel.branch_id == branch_id).all()
    for student in students:
        existing = db.query(GroupStudentModel).filter(
            GroupStudentModel.group_id == target_group_id,
            GroupStudentModel.student_id == student.student_id
        ).first()
        if not existing:
            db.add(GroupStudentModel(group_id=target_group_id, student_id=student.student_id))
    db.commit()

def bulk_add_by_group(db: Session, target_group_id: int, source_group_id: int):
    members = db.query(GroupStudentModel).filter(GroupStudentModel.group_id == source_group_id).all()
    for member in members:
        existing = db.query(GroupStudentModel).filter(
            GroupStudentModel.group_id == target_group_id,
            GroupStudentModel.student_id == member.student_id
        ).first()
        if not existing:
            db.add(GroupStudentModel(group_id=target_group_id, student_id=member.student_id))
    db.commit()

def bulk_add_by_ids(db: Session, target_group_id: int, student_ids: list[str]):
    for student_id in student_ids:
        existing = db.query(GroupStudentModel).filter(
            GroupStudentModel.group_id == target_group_id,
            GroupStudentModel.student_id == student_id
        ).first()
        if not existing:
            db.add(GroupStudentModel(group_id=target_group_id, student_id=student_id))
    db.commit()


def delete_group_student(db: Session, group_id: int, student_id: str):
    entry = db.query(GroupStudentModel).filter(
        GroupStudentModel.group_id == group_id,
        GroupStudentModel.student_id == student_id
    ).first()
    if entry:
        db.delete(entry)
        db.commit()

def bulk_remove_by_ids(db: Session, target_group_id: int, student_ids: list[str]):
    db.query(GroupStudentModel).filter(
        GroupStudentModel.group_id == target_group_id,
        GroupStudentModel.student_id.in_(student_ids)
    ).delete(synchronize_session=False)
    db.commit()
