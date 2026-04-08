from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from datetime import datetime
from backend.database.session import Base


class TeacherModel(Base):

    __tablename__ = "teacher"

    teacher_id = Column(Integer, primary_key=True, autoincrement=True)

    name = Column(String(100), nullable=False)
    code = Column(String(20), nullable=False, unique=True)
    email = Column(String(100))
    
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
