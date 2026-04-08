from sqlalchemy import Column, Integer, String, ForeignKey
from backend.database.session import Base


class TimetableConflictModel(Base):
    __tablename__ = "timetable_conflict"

    conflict_id = Column(Integer, primary_key=True, autoincrement=True)

    version_id = Column(
        Integer,
        ForeignKey("timetable_version.version_id", ondelete="CASCADE"),
        nullable=False,
    )

    session_id = Column(
        Integer,
        ForeignKey("session_table.session_id"),
        nullable=False,
    )

    conflict_type_id = Column(
        Integer,
        ForeignKey("timetable_conflict_type.type_id"),
        nullable=False,
    )

    conflict_level = Column(String(10), nullable=False, default="Hard")

    # The entity involved (teacher/room/group id)
    entity_id = Column(Integer, nullable=True)
    entity_name = Column(String(120), nullable=True)

    # Human-readable timeslot label, e.g. "Monday - Period 2"
    slot_label = Column(String(60), nullable=True)

    # The enrollment being evaluated and the one it conflicted with
    primary_enrollment_id = Column(Integer, nullable=True)
    conflicting_enrollment_id = Column(Integer, nullable=True)
