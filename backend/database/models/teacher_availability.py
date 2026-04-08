from sqlalchemy import Column, Integer, ForeignKey, String, DateTime
from datetime import datetime
from backend.database.session import Base

class TeacherAvailabilityModel(Base):
    """Global/Master Availability Settings"""
    __tablename__ = "teacher_availability"

    teacher_id = Column(Integer, ForeignKey("teacher.teacher_id"), primary_key=True)
    day = Column(String(20), primary_key=True)
    period_number = Column(Integer, primary_key=True)

    preference_rank = Column(Integer, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class SessionTeacherAvailabilityModel(Base):
    """Session-Specific Availability Overrides (Isolated)"""
    __tablename__ = "session_teacher_availability"

    teacher_id = Column(Integer, ForeignKey("teacher.teacher_id"), primary_key=True)
    slot_id = Column(Integer, ForeignKey("session_slot.slot_id", ondelete="CASCADE"), primary_key=True)

    preference_rank = Column(Integer, nullable=True)