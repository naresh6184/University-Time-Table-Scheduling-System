from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from datetime import datetime
from backend.database.session import Base

class SubjectModel(Base):
    __tablename__ = "subject"

    subject_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    code = Column(String(20), nullable=False, unique=True)
    subject_type = Column(String(20), nullable=False)
    hours_per_week = Column(Integer, nullable=False)
    abbreviation = Column(String(50), nullable=True)
    
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
