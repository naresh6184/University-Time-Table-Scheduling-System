from sqlalchemy import Column, Integer, String, ForeignKey
from backend.database.session import Base

class BranchModel(Base):
    __tablename__ = "branch"

    branch_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    abbreviation = Column(String(10), nullable=True)