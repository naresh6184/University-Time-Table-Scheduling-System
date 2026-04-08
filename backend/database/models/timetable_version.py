from sqlalchemy import Column, Integer, DateTime, Boolean, Float, ForeignKey, Text
from datetime import datetime
from backend.database.session import Base


class TimetableVersionModel(Base):
    __tablename__ = "timetable_version"

    session_id = Column(Integer, ForeignKey("session_table.session_id", ondelete="CASCADE"), nullable=False)

    version_id = Column(Integer, primary_key=True, autoincrement=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    population_size = Column(Integer, nullable=False)
    generations = Column(Integer, nullable=False)

    best_violation = Column(Integer, nullable=False)
    best_soft_score = Column(Float, nullable=False)

    is_active = Column(Boolean, default=False)
    
    is_duplicate_of = Column(Integer, ForeignKey("timetable_version.version_id", ondelete="CASCADE"), nullable=True)
    
    # JSON string storing the conflict breakdown from the GA engine
    conflict_json = Column(Text, nullable=True)