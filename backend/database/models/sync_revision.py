from sqlalchemy import Column, Integer, DateTime
from datetime import datetime
from backend.database.session import Base

class MasterSyncRevisionModel(Base):
    """
    Tracks the latest modification time of the Central Database (Master).
    Sessions compare their last_synced_at to this timestamp to detect updates.
    """
    __tablename__ = "master_sync_revision"

    id = Column(Integer, primary_key=True, default=1)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

def touch_master_revision(db):
    """Updates the master sync revision timestamp to current UTC time."""
    rev = db.query(MasterSyncRevisionModel).filter_by(id=1).first()
    if not rev:
        rev = MasterSyncRevisionModel(id=1)
        db.add(rev)
    else:
        rev.last_updated_at = datetime.utcnow()
    db.commit()

def mark_sessions_out_of_sync(db):
    """
    Marks all active sessions as 'out of sync' for structural configurations (Slots/Avail).
    """
    import logging
    logger = logging.getLogger("backend")
    from backend.database.models.session import SessionModel
    
    sessions = db.query(SessionModel).filter(
        SessionModel.session_id != -1
    ).all()
    
    count = 0
    for s in sessions:
        s.has_master_slots_update = True
        count += 1
    
    db.commit()
    logger.info(f"SYNC: Marked {count} session(s) as out-of-sync")
    
    # Also touch the physical timestamp for legacy compatibility
    touch_master_revision(db)
