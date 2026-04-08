from pydantic import BaseModel
from typing import Optional

class TimetableEntrySchema(BaseModel):
    slot_id: int
    subject: str
    group: Optional[str] = None
    teacher: Optional[int] = None
    room_id: Optional[int] = None
    room_type: Optional[str] = None
