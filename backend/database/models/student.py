from sqlalchemy import Column, String, Integer, ForeignKey
from backend.database.session import Base


class StudentModel(Base):

    __tablename__ = "student"

    student_id = Column(String(20), primary_key=True)   # roll number

    name = Column(String(100), nullable=False)

    branch_id = Column(Integer, ForeignKey("branch.branch_id"), nullable=False)

    batch = Column(Integer)

    email = Column(String(100))

    program = Column(String(50), default='B.Tech')