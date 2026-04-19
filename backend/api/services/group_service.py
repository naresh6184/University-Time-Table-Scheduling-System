from sqlalchemy.orm import Session
from backend.database.models.group import GroupModel


def create_group(db: Session, group_data):
    group = GroupModel(**group_data.model_dump())

    db.add(group)
    db.commit()
    db.refresh(group)

    return group


from sqlalchemy import func

def get_all_groups(db: Session):
    results = db.query(GroupModel, func.count(GroupStudentModel.student_id).label("student_count"))\
        .outerjoin(GroupStudentModel, GroupModel.group_id == GroupStudentModel.group_id)\
        .group_by(GroupModel.group_id).all()
        
    groups = []
    for group, count in results:
        group.student_count = count
        groups.append(group)
    return groups

from backend.database.models.student import StudentModel
from backend.database.models.group_student import GroupStudentModel

def get_group_students(db: Session, group_id: int):
    return db.query(StudentModel).join(GroupStudentModel).filter(GroupStudentModel.group_id == group_id).all()


def update_group(db: Session, group_id: int, group_data):
    group = db.query(GroupModel).filter(GroupModel.group_id == group_id).first()
    if group:
        for key, value in group_data.model_dump(exclude_unset=True).items():
            setattr(group, key, value)
        db.commit()
        db.refresh(group)
    return group


from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from backend.database.models.session_entities import SessionGroupModel
from backend.database.models.enrollment import EnrollmentModel
from backend.database.models.timetable_entry import TimetableEntryModel

def delete_group(db: Session, group_id: int):
    group = db.query(GroupModel).filter(GroupModel.group_id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    # 1. Delete group_student memberships
    db.query(GroupStudentModel).filter(GroupStudentModel.group_id == group_id).delete(synchronize_session=False)

    # 2. Delete session_group junction entries
    db.query(SessionGroupModel).filter(SessionGroupModel.group_id == group_id).delete(synchronize_session=False)

    # 3. Delete enrollments and their timetable entries
    enrollments = db.query(EnrollmentModel).filter(EnrollmentModel.group_id == group_id).all()
    for en in enrollments:
        db.query(TimetableEntryModel).filter(TimetableEntryModel.enrollment_id == en.enrollment_id).delete(synchronize_session=False)
        db.delete(en)

    # 4. Delete the group itself
    try:
        db.delete(group)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Cannot delete this group because it is still referenced by other data. Please check enrollments and timetable entries.")
