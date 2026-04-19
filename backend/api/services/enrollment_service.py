from sqlalchemy.orm import Session
from backend.database.models.enrollment import EnrollmentModel


from fastapi import HTTPException
from backend.database.models.session_entities import SessionTeacherModel, SessionSubjectModel, SessionGroupModel

def create_enrollment(db: Session, enrollment_data):
    # Validate session mapping logic
    teacher = db.query(SessionTeacherModel).filter_by(session_id=enrollment_data.session_id, teacher_id=enrollment_data.teacher_id).first()
    if not teacher:
        raise HTTPException(status_code=400, detail="Teacher is not added to this session.")
        
    subject = db.query(SessionSubjectModel).filter_by(session_id=enrollment_data.session_id, subject_id=enrollment_data.subject_id).first()
    if not subject:
        raise HTTPException(status_code=400, detail="Subject is not added to this session.")
        
    group = db.query(SessionGroupModel).filter_by(session_id=enrollment_data.session_id, group_id=enrollment_data.group_id).first()
    if not group:
        raise HTTPException(status_code=400, detail="Group is not added to this session.")

    enrollment = EnrollmentModel(**enrollment_data.model_dump())

    db.add(enrollment)
    db.commit()
    db.refresh(enrollment)

    return enrollment


def update_enrollment(db: Session, enrollment_id: int, update_data):
    enrollment = db.query(EnrollmentModel).filter(EnrollmentModel.enrollment_id == enrollment_id).first()
    if not enrollment:
        return None

    update_dict = update_data.model_dump(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(enrollment, key, value)
        
    db.commit()
    db.refresh(enrollment)
    return enrollment


def get_all_enrollments(db: Session, session_id: int):
    return db.query(EnrollmentModel).filter(EnrollmentModel.session_id == session_id).all()


def delete_enrollment(db: Session, enrollment_id: int):
    from sqlalchemy.exc import IntegrityError
    from backend.database.models.timetable_entry import TimetableEntryModel

    entry = db.query(EnrollmentModel).filter(EnrollmentModel.enrollment_id == enrollment_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Enrollment not found")

    # Clean up any timetable entries referencing this enrollment
    db.query(TimetableEntryModel).filter(TimetableEntryModel.enrollment_id == enrollment_id).delete(synchronize_session=False)

    try:
        db.delete(entry)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Cannot delete this enrollment because it is still referenced by timetable data. Try resetting the timetable first."
        )