from pydantic import BaseModel
from typing import Optional


class EnrollmentCreate(BaseModel):
    session_id: int
    group_id: int
    subject_id: int
    teacher_id: int
    partition: Optional[str] = None


class EnrollmentUpdate(BaseModel):
    group_id: Optional[int] = None
    subject_id: Optional[int] = None
    teacher_id: Optional[int] = None
    partition: Optional[str] = None


class EnrollmentResponse(BaseModel):
    enrollment_id: int
    group_id: int
    subject_id: int
    teacher_id: int
    partition: Optional[str]

    model_config = {"from_attributes": True}