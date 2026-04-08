from pydantic import BaseModel
from typing import Optional

class SubjectCreate(BaseModel):
    name: str
    code: str
    subject_type: str
    hours_per_week: int
    abbreviation: Optional[str] = None

class SubjectUpdate(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None
    subject_type: Optional[str] = None
    hours_per_week: Optional[int] = None
    abbreviation: Optional[str] = None

class SubjectResponse(BaseModel):
    subject_id: int
    name: str
    code: str
    subject_type: str
    hours_per_week: int
    abbreviation: Optional[str] = None

    model_config = {"from_attributes": True}