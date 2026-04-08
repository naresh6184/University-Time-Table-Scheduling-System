from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from datetime import datetime
from backend.database.session import Base

class GroupModel(Base):
    __tablename__ = "group_table"

    group_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    description = Column(String(255), nullable=True)

    # Hierarchical Fields
    program = Column(String(50), nullable=True, default='B.Tech')
    batch = Column(Integer, nullable=True)
    branch_id = Column(Integer, ForeignKey("branch.branch_id"), nullable=True)
    
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)