from sqlalchemy import Column, Integer, String, Boolean, DateTime
from datetime import datetime
from backend.database.session import Base

class SessionModel(Base):
    __tablename__ = "session_table"

    session_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False, unique=True)
    is_active = Column(Boolean, default=True)
    last_synced_at = Column(DateTime, default=datetime.utcnow)
    
    # Flags for Push-Based Synchronization (Physical Clones)
    has_master_slots_update = Column(Boolean, default=False)
    has_master_entities_update = Column(Boolean, default=False)
