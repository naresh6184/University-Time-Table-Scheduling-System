from sqlalchemy import Column, String, Integer, ForeignKey
from backend.database.session import Base


class GroupStudentModel(Base):

    __tablename__ = "group_student"

    group_id = Column(Integer, ForeignKey("group_table.group_id"), primary_key=True)

    student_id = Column(String(20), ForeignKey("student.student_id"), primary_key=True)