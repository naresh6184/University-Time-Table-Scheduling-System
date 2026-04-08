from sqlalchemy import Column, Integer, String, Time, ForeignKey, DateTime
from datetime import datetime
from backend.database.session import Base


class SlotModel(Base):
    __tablename__ = "slot"

    slot_id = Column(Integer, primary_key=True)
    session_id = Column(Integer, ForeignKey("session_table.session_id"), nullable=False)

    day = Column(String(10), nullable=False)
    period_number = Column(Integer, nullable=False)


    start_time = Column(String(10), nullable=False)
    end_time = Column(String(10), nullable=False)
    
    # -1: Blocked, 0: Unavailable (Hidden Row), 1: Available (Check)
    status = Column(Integer, default=1, nullable=False)

    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)