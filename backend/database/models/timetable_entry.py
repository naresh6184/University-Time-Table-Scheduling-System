from sqlalchemy import Column, Integer, ForeignKey
from backend.database.session import Base


class TimetableEntryModel(Base):
    __tablename__ = "timetable_entry"

    entry_id = Column(Integer, primary_key=True, autoincrement=True)

    version_id = Column(Integer, ForeignKey("timetable_version.version_id"), nullable=False)

    enrollment_id = Column(Integer, nullable=False)
    room_id = Column(Integer, nullable=False)
    slot_id = Column(Integer, ForeignKey("session_slot.slot_id", ondelete="CASCADE"), nullable=False)
    duration = Column(Integer, default=1, nullable=False)