from pydantic import BaseModel
from typing import List


class SlotSchema(BaseModel):
    slot_id: int
    day: str
    period_number: int
    start_time: str
    end_time: str
    status: int


class BlockedSlot(BaseModel):
    day: str
    period: int


class SlotConfigureRequest(BaseModel):
    start_hour: int = 9
    end_hour: int = 18
    working_days: List[str] = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    blocked_slots: List[BlockedSlot] = []
