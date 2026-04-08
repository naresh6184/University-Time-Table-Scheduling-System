from sqlalchemy.orm import Session
from backend.database.models.slot import SlotModel
from backend.database.models.session_slot import SessionSlotModel
from backend.database.models.teacher_availability import (
    TeacherAvailabilityModel, SessionTeacherAvailabilityModel
)
from backend.database.models.teacher import TeacherModel
from backend.database.models.timetable_version import TimetableVersionModel
from backend.database.models.timetable_entry import TimetableEntryModel
from backend.api.schemas.slot_schema import SlotConfigureRequest
from backend.database.models.sync_revision import touch_master_revision, mark_sessions_out_of_sync


def get_all_slots(db: Session, session_id: int):
    model = SlotModel if session_id == -1 else SessionSlotModel
    return db.query(model).filter_by(session_id=session_id).order_by(model.slot_id).all()


def configure_slots(db: Session, config: SlotConfigureRequest, session_id: int):
    """
    Unified Status Architecture: STORES ALL SLOTS
    -1: Blocked, 0: Unavailable, 1: Available
    """
    # 1. Snapshot old slots keyed by (day, start_time, end_time)
    model = SlotModel if session_id == -1 else SessionSlotModel
    old_slots = db.query(model).filter_by(session_id=session_id).all()
    # Map: (day, start, end) -> SlotModel/SessionSlotModel
    old_slot_map = { (s.day, s.start_time, s.end_time): s for s in old_slots }

    # 2. Compute the desired new slot configurations (Total Grid)
    blocked = {(b.day, b.period) for b in config.blocked_slots}
    working_day_set = set(config.working_days)
    
    new_slot_params = [] # List of ((day, start, end), period_number, status)
    
    # We iterate ONLY over working days to ensure non-working days are REMOVED from the table
    for day in working_day_set:
        period_number = 1
        for hour in range(config.start_hour, config.end_hour):
            start_t = f"{hour:02d}:00"
            end_t = f"{hour + 1:02d}:00"
            
            # Special Enforcement: Lunch (13:00) is ALWAYS Blocked (-1)
            is_lunch = start_t == "13:00"
            
            if is_lunch:
                status = -1 # Blocked
            elif (day, period_number) in blocked:
                status = -1 # Blocked (by user select)
            else:
                status = 1  # Available
                
            new_slot_params.append(((day, start_t, end_t), period_number, status))
            period_number += 1

    new_signatures = { (p[0][0], p[0][1], p[0][2], p[2]) for p in new_slot_params }
    old_signatures = { (s.day, s.start_time, s.end_time, s.status) for s in old_slots }

    # determine structure-level diff (using Day/Start/End/Status)
    removed_sigs = old_signatures - new_signatures
    added_sigs = new_signatures - old_signatures
    
    # 4. Check if we have real structural changes
    period_shifted = False
    for sig_tuple, p_num, status in new_slot_params:
        sig = sig_tuple # (day, start, end)
        if sig in old_slot_map:
            if old_slot_map[sig].period_number != p_num:
                period_shifted = True
                break
    
    has_changes = bool(removed_sigs or added_sigs or period_shifted)

    # 5. SYNC LOGIC: We process by (Day, Start, End) to update existing rows
    for (day, start_t, end_t), p_num, status in new_slot_params:
        sig = (day, start_t, end_t)
        
        if sig in old_slot_map:
            # Update existing
            db_s = old_slot_map[sig]
            old_status = db_s.status
            db_s.status = status
            db_s.period_number = p_num
            
            # Master Clean-up if status moved from 1 to something else
            if session_id == -1 and old_status == 1 and status != 1:
                db.query(TeacherAvailabilityModel).filter_by(day=day, period_number=p_num).delete(synchronize_session=False)
            
            # Master Addition if status moved from something else to 1
            if session_id == -1 and old_status != 1 and status == 1:
                if start_t != "13:00":
                    teacher_ids = [t.teacher_id for t in db.query(TeacherModel.teacher_id).all()]
                    for t_id in teacher_ids:
                        exists = db.query(TeacherAvailabilityModel).filter_by(teacher_id=t_id, day=day, period_number=p_num).first()
                        if not exists:
                            db.add(TeacherAvailabilityModel(teacher_id=t_id, day=day, period_number=p_num, preference_rank=5))
        else:
            # Add New
            db_s = model(
                session_id=session_id,
                day=day,
                period_number=p_num,
                start_time=start_t,
                end_time=end_t,
                status=status
            )
            db.add(db_s)
            
            if session_id == -1 and status == 1 and start_t != "13:00":
                teacher_ids = [t.teacher_id for t in db.query(TeacherModel.teacher_id).all()]
                for t_id in teacher_ids:
                    db.add(TeacherAvailabilityModel(teacher_id=t_id, day=day, period_number=p_num, preference_rank=5))

    # 6. Cleanup rows that are completely out of the hour range now
    current_signatures = { p[0] for p in new_slot_params }
    for sig, db_s in old_slot_map.items():
        if sig not in current_signatures:
            # Physically remove the row if it's no longer in the grid (e.g. start/end hour changed)
            if session_id == -1 and db_s.status == 1:
                db.query(TeacherAvailabilityModel).filter_by(day=db_s.day, period_number=db_s.period_number).delete(synchronize_session=False)
            db.delete(db_s)

    # 8. Delete timetable versions if anything changed
    if has_changes:
        versions = db.query(TimetableVersionModel).filter_by(session_id=session_id).all()
        v_ids = [v.version_id for v in versions]
        if v_ids:
            db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id.in_(v_ids)).delete(synchronize_session=False)
            db.query(TimetableVersionModel).filter(TimetableVersionModel.version_id.in_(v_ids)).delete(synchronize_session=False)

    db.commit()
    
    # --- TOUCH MASTER REVISION ---
    if session_id == -1:
        mark_sessions_out_of_sync(db)

    # --- PROACTIVE SYNC ---
    # Now that slots exist, ensure all teachers already in the session
    # get their Master availability cloned if they don't have it yet.
    if session_id != -1:
        from backend.api.services.teacher_availability_service import sync_teacher_session_availability
        sync_teacher_session_availability(db, session_id)

    # 9. Build message
    total_slots = len(new_slot_params)
    overlapping_sigs = new_signatures & old_signatures
    
    if not has_changes:
        message = f"Configuration verified. All {total_slots} slots and teacher availability preserved."
    else:
        parts = []
        if removed_sigs: parts.append(f"{len(removed_sigs)} status changes/removals")
        if added_sigs: parts.append(f"{len(added_sigs)} status changes/additions")
        if period_shifted: parts.append("periods reorganized")
        
        message = f"Updated: {', '.join(parts)}. "
        if overlapping_sigs:
            message += f"{len(overlapping_sigs)} slots were unchanged."

    return {
        "message": message,
        "count": total_slots,
        "unchanged": len(overlapping_sigs),
        "removed": len(removed_sigs),
        "added": len(added_sigs),
    }

