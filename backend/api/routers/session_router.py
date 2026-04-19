from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.database.session import get_db
from backend.database.models.session import SessionModel
from backend.api.schemas.session_schema import SessionCreate, SessionSchema, SessionUpdate
from backend.database.models.sync_revision import MasterSyncRevisionModel
from backend.database.models.slot import SlotModel
from backend.database.models.session_slot import SessionSlotModel
from backend.database.models.teacher_availability import SessionTeacherAvailabilityModel
import time
from sqlalchemy.exc import OperationalError

router = APIRouter(
    prefix="/admin/sessions",
    tags=["Sessions"]
)


@router.post("/", response_model=SessionSchema)
def create_session(data: SessionCreate, db: Session = Depends(get_db)):
    existing = db.query(SessionModel).filter(SessionModel.name == data.name).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Session '{data.name}' already exists")

    session = SessionModel(name=data.name, is_active=data.is_active)
    db.add(session)
    db.commit()
    db.refresh(session)
    
    # --- AUTO-INITIALIZE FROM MASTER (-1) ---
    try:
        from backend.api.services.session_copy_service import copy_session_configuration
        copy_session_configuration(
            db, 
            from_session_id=-1, 
            to_session_id=session.session_id,
            copy_slots=True,
            copy_availability=False,
            copy_enrollments=False
        )
        
        # Mark as perfectly synced with everything as of NOW
        from datetime import datetime
        session.last_synced_at = datetime.utcnow()
        session.has_master_slots_update = False
        session.has_master_entities_update = False
        db.commit()
        db.refresh(session)
    except Exception as e:
        print(f"Initial slot sync failed for session {session.session_id}: {e}")
        # Not a fatal error for session creation
        
    return session


@router.get("/", response_model=list[SessionSchema])
def list_sessions(db: Session = Depends(get_db)):
    # Include all sessions except the Central Database (-1)
    return db.query(SessionModel).filter(SessionModel.session_id != -1).order_by(SessionModel.name).all()


@router.get("/{session_id}", response_model=SessionSchema)
def get_session(session_id: int, db: Session = Depends(get_db)):
    session = db.query(SessionModel).filter(SessionModel.session_id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session

@router.put("/{session_id}", response_model=SessionSchema)
def update_session(session_id: int, data: SessionUpdate, db: Session = Depends(get_db)):
    session = db.query(SessionModel).filter(SessionModel.session_id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    session.name = data.name
    db.commit()
    db.refresh(session)
    return session
from backend.database.models.timetable_entry import TimetableEntryModel
from backend.database.models.timetable_version import TimetableVersionModel
from backend.database.models.teacher_availability import SessionTeacherAvailabilityModel
from backend.database.models.slot import SlotModel
from backend.database.models.session_slot import SessionSlotModel
from backend.database.models.enrollment import EnrollmentModel
from backend.database.models.session_entities import (
    SessionTeacherModel, SessionSubjectModel, SessionGroupModel, SessionClassroomModel
)

@router.delete("/{session_id}")
def delete_session(session_id: int, db: Session = Depends(get_db)):
    session = db.query(SessionModel).filter(SessionModel.session_id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    # 1. Clean Timetable Versions and Entries
    versions = db.query(TimetableVersionModel).filter(TimetableVersionModel.session_id == session_id).all()
    version_ids = [v.version_id for v in versions]
    if version_ids:
        db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id.in_(version_ids)).delete(synchronize_session=False)
    db.query(TimetableVersionModel).filter(TimetableVersionModel.session_id == session_id).delete(synchronize_session=False)
        
    # 2. Clean Slots and Teacher Availabilities
    slots = db.query(SessionSlotModel).filter(SessionSlotModel.session_id == session_id).all()
    slot_ids = [s.slot_id for s in slots]
    if slot_ids:
        db.query(SessionTeacherAvailabilityModel).filter(
        SessionTeacherAvailabilityModel.slot_id.in_(
            db.query(SessionSlotModel.slot_id).filter(SessionSlotModel.session_id == session_id)
        )
    ).delete(synchronize_session=False)
    db.query(SessionSlotModel).filter(SessionSlotModel.session_id == session_id).delete(synchronize_session=False)
        
    # 3. Clean Enrollments
    db.query(EnrollmentModel).filter(EnrollmentModel.session_id == session_id).delete(synchronize_session=False)

    # 4. Clean session junction tables
    db.query(SessionTeacherModel).filter(SessionTeacherModel.session_id == session_id).delete(synchronize_session=False)
    db.query(SessionSubjectModel).filter(SessionSubjectModel.session_id == session_id).delete(synchronize_session=False)
    db.query(SessionGroupModel).filter(SessionGroupModel.session_id == session_id).delete(synchronize_session=False)
    db.query(SessionClassroomModel).filter(SessionClassroomModel.session_id == session_id).delete(synchronize_session=False)
    
    # 5. Wipe the Session itself
    db.query(SessionModel).filter(SessionModel.session_id == session_id).delete(synchronize_session=False)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Cannot delete this session because some data still references it. Please try resetting the session first."
        )
    return {"message": "Session cleanly deleted"}
from backend.api.services.session_copy_service import (
    copy_session_configuration,
)


@router.post("/{session_id}/import-data")
def import_session_data(
    session_id: int, 
    from_session_id: int, 
    copy_slots: bool = True,
    copy_availability: bool = True,
    copy_enrollments: bool = True,
    db: Session = Depends(get_db)
):
    """
    Import configuration data from one session into this one.
    """
    return copy_session_configuration(
        db, 
        from_session_id, 
        session_id,
        copy_slots=copy_slots,
        copy_availability=copy_availability,
        copy_enrollments=copy_enrollments
    )

from backend.api.schemas.teacher_schema import TeacherResponse
from backend.api.schemas.subject_schema import SubjectResponse
from backend.api.schemas.group_schema import GroupResponse
from backend.api.schemas.classroom_schema import ClassroomResponse
from backend.api.services.session_entities_service import (
    get_session_teachers, add_teacher_to_session, remove_teacher_from_session,
    get_session_subjects, add_subject_to_session, remove_subject_from_session,
    get_session_groups, add_group_to_session, remove_group_from_session,
    get_session_rooms, add_room_to_session, remove_room_from_session,
)

# Teachers
@router.get("/{session_id}/teachers", response_model=list[TeacherResponse])
def get_session_teachers_route(session_id: int, db: Session = Depends(get_db)):
    return get_session_teachers(db, session_id)

@router.post("/{session_id}/teachers/{teacher_id}")
def add_session_teacher(session_id: int, teacher_id: int, db: Session = Depends(get_db)):
    return add_teacher_to_session(db, session_id, teacher_id)

@router.delete("/{session_id}/teachers/{teacher_id}")
def remove_session_teacher(session_id: int, teacher_id: int, db: Session = Depends(get_db)):
    return remove_teacher_from_session(db, session_id, teacher_id)

# Subjects
@router.get("/{session_id}/subjects", response_model=list[SubjectResponse])
def get_session_subjects_route(session_id: int, db: Session = Depends(get_db)):
    return get_session_subjects(db, session_id)

@router.post("/{session_id}/subjects/{subject_id}")
def add_session_subject(session_id: int, subject_id: int, db: Session = Depends(get_db)):
    return add_subject_to_session(db, session_id, subject_id)

@router.delete("/{session_id}/subjects/{subject_id}")
def remove_session_subject(session_id: int, subject_id: int, db: Session = Depends(get_db)):
    return remove_subject_from_session(db, session_id, subject_id)

# Groups
@router.get("/{session_id}/groups", response_model=list[GroupResponse])
def get_session_groups_route(session_id: int, db: Session = Depends(get_db)):
    return get_session_groups(db, session_id)

@router.post("/{session_id}/groups/{group_id}")
def add_session_group(session_id: int, group_id: int, db: Session = Depends(get_db)):
    return add_group_to_session(db, session_id, group_id)

@router.delete("/{session_id}/groups/{group_id}")
def remove_session_group(session_id: int, group_id: int, db: Session = Depends(get_db)):
    return remove_group_from_session(db, session_id, group_id)

# Rooms
@router.get("/{session_id}/rooms", response_model=list[ClassroomResponse])
def get_session_rooms_route(session_id: int, db: Session = Depends(get_db)):
    return get_session_rooms(db, session_id)

@router.post("/{session_id}/rooms/{room_id}")
def add_session_room(session_id: int, room_id: int, db: Session = Depends(get_db)):
    return add_room_to_session(db, session_id, room_id)

@router.delete("/{session_id}/rooms/{room_id}")
def remove_session_room(session_id: int, room_id: int, db: Session = Depends(get_db)):
    return remove_room_from_session(db, session_id, room_id)
from sqlalchemy import func
from backend.database.models.teacher import TeacherModel
from backend.database.models.subject import SubjectModel
from backend.database.models.classroom import ClassroomModel
from backend.database.models.group import GroupModel
from backend.database.models.sync_revision import MasterSyncRevisionModel
from backend.api.services.teacher_availability_service import sync_teacher_session_availability

@router.get("/{session_id}/sync-status")
def get_session_sync_status(session_id: int, db: Session = Depends(get_db)):
    import logging
    logger = logging.getLogger("backend")
    
    session = db.query(SessionModel).filter(SessionModel.session_id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    has_master_config_update = session.has_master_slots_update
    has_master_entities_update = getattr(session, 'has_master_entities_update', False)
    
    out_of_sync = bool(has_master_config_update or has_master_entities_update)
    
    if out_of_sync:
        logger.info(f"SYNC-STATUS session={session_id}: OUT OF SYNC (slots={has_master_config_update}, entities={has_master_entities_update})")

    return {
        "out_of_sync": out_of_sync,
        "details": {
            "master_config": has_master_config_update,
            "availability": has_master_config_update,
            "basic_entities": has_master_entities_update
        },
        "last_synced_at": session.last_synced_at
    }

@router.post("/{session_id}/sync-trigger")
def trigger_session_sync(session_id: int, ignore_availability: bool = False, db: Session = Depends(get_db)):
    session = db.query(SessionModel).filter(SessionModel.session_id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    from datetime import datetime
    from backend.api.services.session_copy_service import copy_session_configuration
    
    # 1. Update Slots if they changed in Master
    # We always do this if we are doing a "Sync All" (ignore_availability=false)
    # or if we detect they are out of sync.
    # 1. Update Slots if they changed in Master
    if not ignore_availability:
        # Check if slots exist for master
        master_slots = db.query(SlotModel).filter_by(session_id=-1).all()
        if master_slots:
            # Simple retry loop for "database is locked"
            max_retries = 3
            for attempt in range(max_retries):
                try:
                    # Get current session slot IDs
                    old_slots = db.query(SessionSlotModel).filter_by(session_id=session_id).all()
                    old_slot_ids = [s.slot_id for s in old_slots]
                    
                    # Wipe dependent availability FIRST
                    if old_slot_ids:
                        db.query(SessionTeacherAvailabilityModel).filter(
                            SessionTeacherAvailabilityModel.slot_id.in_(old_slot_ids)
                        ).delete(synchronize_session='fetch')

                    # Wipe existing session slots 
                    db.query(SessionSlotModel).filter_by(session_id=session_id).delete(synchronize_session='fetch')
                    
                    # CRITICAL: Ensure ORM memory is clean before creating new objects with possible ID reuse
                    db.flush()
                    db.expire_all()
                    
                    # Re-copy Master slots
                    copy_session_configuration(
                        db, 
                        from_session_id=-1, 
                        to_session_id=session_id,
                        copy_slots=True,
                        copy_availability=False,
                        copy_enrollments=False
                    )
                    break # Success
                except OperationalError as e:
                    if "locked" in str(e).lower() and attempt < max_retries - 1:
                        time.sleep(1)
                        continue
                    raise HTTPException(status_code=503, detail="Database is busy, please try again in a moment")

    # 2. Re-sync Teacher Availability if not ignored
    if not ignore_availability:
        # Sync all teachers in session with Master availability, forcing overrides to clear
        sync_teacher_session_availability(db, session_id, force=True)
            
    # 3. Update Sync State
    from datetime import datetime
    session.last_synced_at = datetime.utcnow()
    session.has_master_slots_update = False
    
    db.commit()
    
    return {"message": "Sync completed successfully"}
