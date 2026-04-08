from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from datetime import datetime
from backend.database.session import Base


class ClassroomModel(Base):

    __tablename__ = "classroom"

    room_id = Column(Integer, primary_key=True, autoincrement=True)

    name = Column(String(20), nullable=False)   # AB101, LAB3 etc
    capacity = Column(Integer, nullable=False)

    room_type = Column(String(20), nullable=False)  # theory / lab
    
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)