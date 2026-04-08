from sqlalchemy.orm import Session
from backend.database.models import SlotModel, SessionTeacherAvailabilityModel, EnrollmentModel, TeacherAvailabilityModel
from backend.database.models.session_slot import SessionSlotModel

def copy_session_configuration(db: Session, from_session_id: int, to_session_id: int, copy_slots: bool = True, copy_availability: bool = True, copy_enrollments: bool = True):
    """
    Copies configuration data from one session to another.
    Crucial: Does not perform its own commits to maintain transaction atomicity.
    """
    
    # 1. Copy Slots
    if copy_slots:
        from_model = SlotModel if from_session_id == -1 else SessionSlotModel
        old_slots = db.query(from_model).filter(from_model.session_id == from_session_id).all()
        for s in old_slots:
            new_slot = SessionSlotModel(
                session_id=to_session_id,
                day=s.day,
                start_time=s.start_time,
                end_time=s.end_time,
                period_number=s.period_number,
                status=s.status
            )
            db.add(new_slot)
        db.flush()

    # 2. Copy Teacher Availability
    if copy_availability:
        from_model = SlotModel if from_session_id == -1 else SessionSlotModel
        old_slots = db.query(from_model).filter(from_model.session_id == from_session_id).all()
        old_slot_map = {s.slot_id: s for s in old_slots}
        
        new_slots = db.query(SessionSlotModel).filter(SessionSlotModel.session_id == to_session_id).all()
        new_slot_map = {f"{ns.day}-{ns.period_number}": ns.slot_id for ns in new_slots}
        
        if from_session_id == -1:
            # Copy from GLOBAL Master
            old_avail = db.query(TeacherAvailabilityModel).all()
            for ta in old_avail:
                new_slot_id = new_slot_map.get(f"{ta.day}-{ta.period_number}")
                if new_slot_id:
                    new_ta = SessionTeacherAvailabilityModel(
                        teacher_id=ta.teacher_id,
                        slot_id=new_slot_id,
                        preference_rank=ta.preference_rank
                    )
                    db.add(new_ta)
        else:
            # Copy from another SESSION
            old_avail = db.query(SessionTeacherAvailabilityModel).filter(
                SessionTeacherAvailabilityModel.slot_id.in_(old_slot_map.keys())
            ).all() if old_slot_map else []
            
            for ta in old_avail:
                s_info = old_slot_map.get(ta.slot_id)
                if s_info:
                    new_slot_id = new_slot_map.get(f"{s_info.day}-{s_info.period_number}")
                    if new_slot_id:
                        new_ta = SessionTeacherAvailabilityModel(
                            teacher_id=ta.teacher_id,
                            slot_id=new_slot_id,
                            preference_rank=ta.preference_rank
                        )
                        db.add(new_ta)
        db.flush()

    # 3. Copy Enrollments
    if copy_enrollments:
        old_enrollments = db.query(EnrollmentModel).filter(EnrollmentModel.session_id == from_session_id).all()
        for e in old_enrollments:
            new_enrollment = EnrollmentModel(
                session_id=to_session_id,
                group_id=e.group_id,
                subject_id=e.subject_id,
                teacher_id=e.teacher_id,
                partition=e.partition
            )
            db.add(new_enrollment)
        db.flush()

    return {"status": "success", "message": "Data copied successfully"}

