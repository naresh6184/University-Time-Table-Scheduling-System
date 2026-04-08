from sqlalchemy import Column, Integer, String
from backend.database.session import Base


class TimetableConflictTypeModel(Base):
    __tablename__ = "timetable_conflict_type"

    type_id = Column(Integer, primary_key=True)
    name = Column(String(50), nullable=False, unique=True)
    weight = Column(Integer, nullable=True)
