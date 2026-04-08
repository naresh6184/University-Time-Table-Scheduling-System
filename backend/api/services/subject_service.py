from sqlalchemy.orm import Session
from backend.database.models.subject import SubjectModel

from fastapi import HTTPException

def create_subject(db: Session, subject_data):
    if db.query(SubjectModel).filter((SubjectModel.name == subject_data.name) | (SubjectModel.code == subject_data.code)).first():
        raise HTTPException(status_code=400, detail=f"A subject with name '{subject_data.name}' or code '{subject_data.code}' already exists")
        
    subject = SubjectModel(
        name=subject_data.name,
        code=subject_data.code,
        subject_type=subject_data.subject_type,
        hours_per_week=subject_data.hours_per_week,
        abbreviation=subject_data.abbreviation
    )

    db.add(subject)
    db.commit()
    db.refresh(subject)
    return subject

def get_subject(db: Session, subject_id: int):
    return db.query(SubjectModel).filter(SubjectModel.subject_id == subject_id).first()


def get_all_subjects(db: Session):
    return db.query(SubjectModel).all()

from sqlalchemy.exc import IntegrityError
from backend.database.models.session_entities import SessionSubjectModel
from backend.database.models.enrollment import EnrollmentModel
from backend.database.models.timetable_entry import TimetableEntryModel

def delete_subject(db: Session, subject_id: int):
    subject = db.query(SubjectModel).filter(SubjectModel.subject_id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    # 1. Delete session_subject junction entries
    db.query(SessionSubjectModel).filter(SessionSubjectModel.subject_id == subject_id).delete(synchronize_session=False)

    # 2. Delete enrollments and their timetable entries
    enrollments = db.query(EnrollmentModel).filter(EnrollmentModel.subject_id == subject_id).all()
    for en in enrollments:
        db.query(TimetableEntryModel).filter(TimetableEntryModel.enrollment_id == en.enrollment_id).delete(synchronize_session=False)
        db.delete(en)

    # 3. Delete the subject itself
    try:
        db.delete(subject)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Cannot delete subject due to existing constraints.")

def update_subject(db: Session, subject_id: int, subject_data):
    if hasattr(subject_data, 'name') and subject_data.name:
        existing = db.query(SubjectModel).filter(
            ((SubjectModel.name == subject_data.name) | (SubjectModel.code == subject_data.code)),
            SubjectModel.subject_id != subject_id
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail=f"A subject with this name or code already exists")
            
    subject = get_subject(db, subject_id)
    if subject:
        for key, value in subject_data.model_dump(exclude_unset=True).items():
            setattr(subject, key, value)
        db.commit()
        db.refresh(subject)
    return subject
