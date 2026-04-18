from sqlalchemy import func
from sqlalchemy.orm import Session
from fastapi import HTTPException
from backend.database.models.teacher import TeacherModel
from backend.database.models.subject import SubjectModel
from backend.database.models.group import GroupModel
from backend.database.models.classroom import ClassroomModel
from backend.database.models.slot import SlotModel
from backend.database.models.session_slot import SessionSlotModel
from backend.database.models.teacher_availability import (
    TeacherAvailabilityModel,
    SessionTeacherAvailabilityModel
)

from backend.database.models.group_student import GroupStudentModel
from backend.database.models.session_entities import (
    SessionTeacherModel,
    SessionSubjectModel,
    SessionGroupModel,
    SessionClassroomModel,
)

# --- Teachers ---
def get_session_teachers(db: Session, session_id: int):
    return db.query(TeacherModel).join(SessionTeacherModel, TeacherModel.teacher_id == SessionTeacherModel.teacher_id).filter(SessionTeacherModel.session_id == session_id).all()

def add_teacher_to_session(db: Session, session_id: int, teacher_id: int):
    from backend.api.services.teacher_availability_service import sync_teacher_session_availability
    
    existing = db.query(SessionTeacherModel).filter_by(session_id=session_id, teacher_id=teacher_id).first()
    if not existing:
        db.add(SessionTeacherModel(session_id=session_id, teacher_id=teacher_id))
        db.flush()

    # --- Check for Session Slots ---
    # We must have session slots before we can sync availability
    has_slots = db.query(SessionSlotModel).filter_by(session_id=session_id).first()
    if has_slots:
        # --- Robust Sync: Pull direct from central with force=True for fresh start ---
        sync_teacher_session_availability(db, session_id, teacher_id, force=True)
    
    db.commit()

    return {"message": "Success"}

def remove_teacher_from_session(db: Session, session_id: int, teacher_id: int):
    # 1. Remove junction entry
    db.query(SessionTeacherModel).filter_by(session_id=session_id, teacher_id=teacher_id).delete()
    
    # 2. CLEANUP: Remove session-specific availability overrides
    db.query(SessionTeacherAvailabilityModel).filter(
        SessionTeacherAvailabilityModel.teacher_id == teacher_id,
        SessionTeacherAvailabilityModel.slot_id.in_(
            db.query(SessionSlotModel.slot_id).filter(SessionSlotModel.session_id == session_id)
        )
    ).delete(synchronize_session=False)

    db.commit()
    return {"message": "Success"}

# --- Subjects ---
def get_session_subjects(db: Session, session_id: int):
    return db.query(SubjectModel).join(SessionSubjectModel, SubjectModel.subject_id == SessionSubjectModel.subject_id).filter(SessionSubjectModel.session_id == session_id).all()

def add_subject_to_session(db: Session, session_id: int, subject_id: int):
    existing = db.query(SessionSubjectModel).filter_by(session_id=session_id, subject_id=subject_id).first()
    if not existing:
        db.add(SessionSubjectModel(session_id=session_id, subject_id=subject_id))
        db.commit()
    return {"message": "Success"}

def remove_subject_from_session(db: Session, session_id: int, subject_id: int):
    db.query(SessionSubjectModel).filter_by(session_id=session_id, subject_id=subject_id).delete()
    db.commit()
    return {"message": "Success"}


# --- Groups ---
def get_session_groups(db: Session, session_id: int):
    # 1. Get IDs of groups linked to this session
    session_group_ids = db.query(SessionGroupModel.group_id).filter(SessionGroupModel.session_id == session_id).all()
    group_ids = [g[0] for g in session_group_ids]

    if not group_ids:
        return []

    # 2. Fetch those groups with their individual student counts
    results = db.query(GroupModel, func.count(GroupStudentModel.student_id).label("student_count"))\
        .outerjoin(GroupStudentModel, GroupModel.group_id == GroupStudentModel.group_id)\
        .filter(GroupModel.group_id.in_(group_ids))\
        .group_by(GroupModel.group_id).all()

    groups = []
    for group, count in results:
        group.student_count = count
        groups.append(group)
    return groups

def add_group_to_session(db: Session, session_id: int, group_id: int):
    existing = db.query(SessionGroupModel).filter_by(session_id=session_id, group_id=group_id).first()
    if not existing:
        db.add(SessionGroupModel(session_id=session_id, group_id=group_id))
        db.commit()
    return {"message": "Success"}

def remove_group_from_session(db: Session, session_id: int, group_id: int):
    db.query(SessionGroupModel).filter_by(session_id=session_id, group_id=group_id).delete()
    db.commit()
    return {"message": "Success"}


# --- Rooms ---
def get_session_rooms(db: Session, session_id: int):
    return db.query(ClassroomModel).join(SessionClassroomModel, ClassroomModel.room_id == SessionClassroomModel.room_id).filter(SessionClassroomModel.session_id == session_id).all()

def add_room_to_session(db: Session, session_id: int, room_id: int):
    existing = db.query(SessionClassroomModel).filter_by(session_id=session_id, room_id=room_id).first()
    if not existing:
        db.add(SessionClassroomModel(session_id=session_id, room_id=room_id))
        db.commit()
    return {"message": "Success"}

def remove_room_from_session(db: Session, session_id: int, room_id: int):
    db.query(SessionClassroomModel).filter_by(session_id=session_id, room_id=room_id).delete()
    db.commit()
    return {"message": "Success"}
