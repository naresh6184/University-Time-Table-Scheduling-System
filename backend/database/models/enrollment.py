from sqlalchemy import Column, Integer, ForeignKey,String
from backend.database.session import Base

class EnrollmentModel(Base):
    __tablename__ = "enrollment"

    session_id = Column(Integer, ForeignKey("session_table.session_id", ondelete="CASCADE"), nullable=False)

    enrollment_id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("group_table.group_id"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subject.subject_id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("teacher.teacher_id"), nullable=False)
    
    partition = Column(String(50), nullable=True)