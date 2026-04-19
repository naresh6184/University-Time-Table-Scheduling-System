from sqlalchemy.orm import Session
from backend.database.models.teacher import TeacherModel
from backend.database.models.teacher_availability import TeacherAvailabilityModel

from fastapi import HTTPException

def create_teacher(db: Session, teacher_data):
    if db.query(TeacherModel).filter((TeacherModel.name == teacher_data.name) | (TeacherModel.code == teacher_data.code)).first():
        raise HTTPException(status_code=400, detail=f"A teacher with name '{teacher_data.name}' or code '{teacher_data.code}' already exists")
        
    teacher = TeacherModel(
        name=teacher_data.name,
        code=teacher_data.code,
        email=teacher_data.email
    )

    db.add(teacher)
    db.flush() # Get teacher_id before commit
    
    # --- AUTO-INITIALIZE GLOBAL AVAILABILITY based on Master Slot Config ---
    from backend.database.models.slot import SlotModel
    
    # Fetch Master Slots (session_id = -1)
    master_slots = db.query(SlotModel).filter_by(session_id=-1).all()
    
    if master_slots:
        for slot in master_slots:
            # We assume "period_number == 5" is lunch globally as per convention in current code
            if slot.period_number == 5:
                continue
                
            db.add(TeacherAvailabilityModel(
                teacher_id=teacher.teacher_id,
                day=slot.day,
                period_number=slot.period_number,
                preference_rank=5 # Neutral/Available
            ))
    else:
        # Fallback to hardcoded defaults if no master config exists yet
        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        for day in days:
            for period in range(1, 10): # Periods 1-9
                if period == 5: continue # Skip Lunch
                
                db.add(TeacherAvailabilityModel(
                    teacher_id=teacher.teacher_id,
                    day=day,
                    period_number=period,
                    preference_rank=5 # Neutral/Available
                ))

    db.commit()
    db.refresh(teacher)
    return teacher

def get_teacher(db: Session, teacher_id: int):
    return db.query(TeacherModel).filter(TeacherModel.teacher_id == teacher_id).first()

def get_all_teachers(db: Session):
    return db.query(TeacherModel).all()

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from backend.database.models.teacher_availability import TeacherAvailabilityModel, SessionTeacherAvailabilityModel
from backend.database.models.enrollment import EnrollmentModel
from backend.database.models.timetable_entry import TimetableEntryModel
from backend.database.models.session_entities import SessionTeacherModel

def delete_teacher(db: Session, teacher_id: int):
    teacher = db.query(TeacherModel).filter(TeacherModel.teacher_id == teacher_id).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")

    # 1. Delete Availabilities (Global and Session)
    db.query(TeacherAvailabilityModel).filter(TeacherAvailabilityModel.teacher_id == teacher_id).delete(synchronize_session=False)
    db.query(SessionTeacherAvailabilityModel).filter(SessionTeacherAvailabilityModel.teacher_id == teacher_id).delete(synchronize_session=False)

    # 2. Delete session_teacher junction entries
    db.query(SessionTeacherModel).filter(SessionTeacherModel.teacher_id == teacher_id).delete(synchronize_session=False)
        
    # 3. Get Enrollments and delete associated Timetable Entries
    enrollments = db.query(EnrollmentModel).filter(EnrollmentModel.teacher_id == teacher_id).all()
    for en in enrollments:
        db.query(TimetableEntryModel).filter(TimetableEntryModel.enrollment_id == en.enrollment_id).delete(synchronize_session=False)
        db.delete(en)
            
    # 4. Delete Teacher
    try:
        db.delete(teacher)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Cannot delete this teacher because they are still referenced by other data. Please check enrollments and timetable entries.")

def update_teacher(db: Session, teacher_id: int, teacher_data):
    if hasattr(teacher_data, 'name') and teacher_data.name:
        existing = db.query(TeacherModel).filter(
            ((TeacherModel.name == teacher_data.name) | (TeacherModel.code == teacher_data.code)),
            TeacherModel.teacher_id != teacher_id
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail=f"A teacher with this name or code already exists")
            
    teacher = get_teacher(db, teacher_id)
    if teacher:
        for key, value in teacher_data.model_dump(exclude_unset=True).items():
            setattr(teacher, key, value)
        db.commit()
        db.refresh(teacher)
    return teacher
