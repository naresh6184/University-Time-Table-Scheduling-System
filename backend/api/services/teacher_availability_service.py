from sqlalchemy.orm import Session
from backend.database.models.teacher_availability import TeacherAvailabilityModel, SessionTeacherAvailabilityModel
from backend.database.models.slot import SlotModel
from backend.database.models.session_slot import SessionSlotModel
from backend.api.schemas.teacher_availability_schema import BulkTeacherAvailabilityRequest
from backend.database.models.sync_revision import touch_master_revision, mark_sessions_out_of_sync


def get_teacher_availability(db: Session, teacher_id: int, session_id: int = -1):
    # --- STRICT ISOLATION MODE ---
    # If session_id is provided, fetch ONLY from session-specific table
    if session_id != -1:
        entries = db.query(SessionTeacherAvailabilityModel).join(
            SessionSlotModel, SessionSlotModel.slot_id == SessionTeacherAvailabilityModel.slot_id
        ).filter(
            SessionTeacherAvailabilityModel.teacher_id == teacher_id,
            SessionSlotModel.session_id == session_id,
            SessionSlotModel.status == 1
        ).all()
        return {
            "teacher_id": teacher_id,
            "session_id": session_id,
            "entries": [{"slot_id": e.slot_id, "preference_rank": e.preference_rank} for e in entries]
        }
    
    # Global Mode: Fetch ONLY from master table
    master = db.query(TeacherAvailabilityModel).filter(
        TeacherAvailabilityModel.teacher_id == teacher_id
    ).all()
    return {
        "teacher_id": teacher_id,
        "session_id": session_id,
        "entries": [{"day": m.day, "period": m.period_number, "preference_rank": m.preference_rank} for m in master]
    }


def bulk_update_teacher_availability(db: Session, teacher_id: int, data: BulkTeacherAvailabilityRequest, session_id: int = -1, all_slots: list = None):
    # If session_id is provided, we update ONLY the session-specific table
    if session_id != -1:
        # 1. Clear existing session-specific records
        db.query(SessionTeacherAvailabilityModel).filter(
            SessionTeacherAvailabilityModel.teacher_id == teacher_id,
            SessionTeacherAvailabilityModel.slot_id.in_(
                db.query(SessionSlotModel.slot_id).filter(
                    SessionSlotModel.session_id == session_id,
                    SessionSlotModel.status == 1
                )
            )
        ).delete(synchronize_session=False)
        db.flush()

        # 2. Insert new session records
        new_entries = []
        for e in data.entries:
            entry = SessionTeacherAvailabilityModel(
                teacher_id=teacher_id,
                slot_id=e.slot_id,
                preference_rank=e.preference_rank
            )
            db.add(entry)
            new_entries.append(entry)
        db.commit()
        return {"message": f"Updated {len(new_entries)} session-specific records for teacher {teacher_id}"}
    
    # --- Global Mode Update (Central Database) ---
    # 1. Clear existing master settings
    db.query(TeacherAvailabilityModel).filter(
        TeacherAvailabilityModel.teacher_id == teacher_id
    ).delete()
    db.flush()

    # 2. Insert new master settings
    new_entries = []
    for e in data.entries:
        day = None
        period = None
        
        if all_slots:
            slot_info = next((s for s in all_slots if s.get('slot_id') == e.slot_id), None)
            if slot_info:
                day = slot_info.get('day')
                period = slot_info.get('period')

        if day and period is not None:
            entry = TeacherAvailabilityModel(
                teacher_id=teacher_id,
                day=day,
                period_number=period,
                preference_rank=e.preference_rank
            )
            db.add(entry)
            new_entries.append(entry)
            
    db.commit()
    
    # --- TOUCH MASTER REVISION ---
    if session_id == -1:
        mark_sessions_out_of_sync(db)
        
    return {"message": f"Updated {len(new_entries)} global master records for teacher {teacher_id}"}


def add_teacher_availability(db: Session, data):
    # Default to session-specific if slot_id is provided, otherwise global
    # This is a legacy helper, but let's make it safe
    if hasattr(data, 'slot_id') and data.slot_id > 0:
        entry = SessionTeacherAvailabilityModel(**data.model_dump())
    else:
        entry = TeacherAvailabilityModel(**data.model_dump())
    db.add(entry)
    db.commit()
    
    # --- TOUCH MASTER REVISION (Global) ---
    if not hasattr(data, 'slot_id') or data.slot_id <= 0:
        mark_sessions_out_of_sync(db)
        
    return entry


def sync_teacher_session_availability(db: Session, session_id: int, teacher_id: int = None, force: bool = False):
    """
    Synchronizes Master availability into Session availability for teachers in a session.
    Only fills in slots for teachers who have ZERO availability records in the session, 
    to avoid overwriting manual overrides.
    If force is True, overwrites even if records exist.
    """
    from backend.database.models.session_entities import SessionTeacherModel

    # 1. Determine which teachers to sync
    if teacher_id:
        target_teacher_ids = [teacher_id]
    else:
        # Get all teachers currently in this session
        target_teacher_ids = [t.teacher_id for t in db.query(SessionTeacherModel).filter_by(session_id=session_id).all()]

    if not target_teacher_ids:
        return

    # 2. Get all slots for THIS session
    session_slots = db.query(SessionSlotModel).filter(
        SessionSlotModel.session_id == session_id,
        SessionSlotModel.status == 1
    ).all()
    if not session_slots:
        return

    for t_id in target_teacher_ids:
        # 1. Handle Deletion (if forced or not existing)
        if force:
            # Wipe existing session availability for THIS teacher (Save using subquery for SQLAlchemy compatibility)
            session_slot_ids = db.query(SessionSlotModel.slot_id).filter(SessionSlotModel.session_id == session_id)
            db.query(SessionTeacherAvailabilityModel).filter(
                SessionTeacherAvailabilityModel.teacher_id == t_id,
                SessionTeacherAvailabilityModel.slot_id.in_(session_slot_ids)
            ).delete(synchronize_session=False)
            db.flush()
        else:
            # Check if teacher ALREADY has any records in this session's availability
            existing_count = db.query(SessionTeacherAvailabilityModel).join(
                SessionSlotModel, SessionSlotModel.slot_id == SessionTeacherAvailabilityModel.slot_id
            ).filter(
                SessionTeacherAvailabilityModel.teacher_id == t_id,
                SessionSlotModel.session_id == session_id
            ).count()

            if existing_count > 0:
                continue # Already configured or synced, skip

        # Fetch Global Master availability for this teacher
        master_avail = db.query(TeacherAvailabilityModel).filter(
            TeacherAvailabilityModel.teacher_id == t_id
        ).all()

        # 3. Create session-specific records for EVERY slot
        for s in session_slots:
            s_day_short = (s.day or "")[:3].lower()
            
            # Find matching master override
            matching_override = next((
                ma for ma in master_avail 
                if (ma.day or "")[:3].lower() == s_day_short and ma.period_number == s.period_number
            ), None)

            # --- EXACT MIRROR LOGIC ---
            # If no override in Central, we don't create one in the Session.
            # This causes the UI to show 'Unavailable' (🚫) correctly.
            if matching_override:
                db.add(SessionTeacherAvailabilityModel(
                    teacher_id=t_id,
                    slot_id=s.slot_id,
                    preference_rank=matching_override.preference_rank
                ))
    
    db.commit()