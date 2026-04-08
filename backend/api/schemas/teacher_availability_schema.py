from pydantic import BaseModel
from typing import List, Optional, Any, Dict


class TeacherAvailabilityCreate(BaseModel):
    teacher_id: int
    slot_id: int
    preference_rank: Optional[int] = 5


class TeacherAvailabilityEntry(BaseModel):
    slot_id: int
    preference_rank: int


class BulkTeacherAvailabilityRequest(BaseModel):
    entries: List[TeacherAvailabilityEntry]
    all_slots: Optional[List[Dict[str, Any]]] = None