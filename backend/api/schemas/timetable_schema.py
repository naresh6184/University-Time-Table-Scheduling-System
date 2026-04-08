from pydantic import BaseModel
from typing import List, Optional, Dict

from backend.api.schemas.timetable_entry_schema import TimetableEntrySchema

class TimetableResponse(BaseModel):
    timetable: List[TimetableEntrySchema]


class GroupTimetableResponse(BaseModel):
    group_id: int
    timetable: List[TimetableEntrySchema]


class TeacherTimetableResponse(BaseModel):
    teacher_id: int
    timetable: List[TimetableEntrySchema]


class RoomTimetableResponse(BaseModel):
    room_id: int
    timetable: List[TimetableEntrySchema]


class GridCell(BaseModel):
    subject: Optional[str] = None
    group: Optional[str] = None
    teacher: Optional[str] = None
    room: Optional[str] = None
    duration: int = 1
    isContinuation: bool = False

    # Allow extra fields if future grid types add more info
    model_config = {"extra": "allow"}


class PeriodMeta(BaseModel):
    period: int
    start: str
    end: str


class GridResponse(BaseModel):
    periods: List[PeriodMeta]
    grid: Dict[str, List[Optional[GridCell]]]


class BranchTimetableEntry(BaseModel):
    enrollment_id: int
    room_id: int
    slot_id: int


class BranchTimetableResponse(BaseModel):
    branch_id: int
    timetable: List[BranchTimetableEntry]




class TeacherConflict(BaseModel):
    teacher_id: int
    slot_id: int


class RoomConflict(BaseModel):
    room_id: int
    slot_id: int


class GroupConflict(BaseModel):
    group_id: int
    slot_id: int


class ConflictResponse(BaseModel):
    teacher_conflicts: List[TeacherConflict]
    room_conflicts: List[RoomConflict]
    group_conflicts: List[GroupConflict]


class InstituteTimetableResponse(BaseModel):
    periods: List[PeriodMeta]
    groups: Dict[int, Dict[str, List[Optional[GridCell]]]]
    teachers: Dict[int, Dict[str, List[Optional[GridCell]]]]
    rooms: Dict[int, Dict[str, List[Optional[GridCell]]]]


class PartitionUpdate(BaseModel):
    partition: List[int]
    

