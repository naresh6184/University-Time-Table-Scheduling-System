from sqlalchemy import Column, Integer, ForeignKey
from backend.database.session import Base


class SessionTeacherModel(Base):
    __tablename__ = "session_teacher"

    session_id = Column(Integer, ForeignKey("session_table.session_id", ondelete="CASCADE"), primary_key=True)
    teacher_id = Column(Integer, ForeignKey("teacher.teacher_id", ondelete="CASCADE"), primary_key=True)


class SessionSubjectModel(Base):
    __tablename__ = "session_subject"

    session_id = Column(Integer, ForeignKey("session_table.session_id", ondelete="CASCADE"), primary_key=True)
    subject_id = Column(Integer, ForeignKey("subject.subject_id", ondelete="CASCADE"), primary_key=True)


class SessionGroupModel(Base):
    __tablename__ = "session_group"

    session_id = Column(Integer, ForeignKey("session_table.session_id", ondelete="CASCADE"), primary_key=True)
    group_id = Column(Integer, ForeignKey("group_table.group_id", ondelete="CASCADE"), primary_key=True)


class SessionClassroomModel(Base):
    __tablename__ = "session_classroom"

    session_id = Column(Integer, ForeignKey("session_table.session_id", ondelete="CASCADE"), primary_key=True)
    room_id = Column(Integer, ForeignKey("classroom.room_id", ondelete="CASCADE"), primary_key=True)
