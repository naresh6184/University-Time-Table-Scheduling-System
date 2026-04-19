from pydantic import BaseModel


class StudentCreate(BaseModel):
    student_id: str
    name: str
    branch_id: int
    batch: int | None = None
    email: str | None = None
    program: str = "B.Tech"


class StudentUpdate(BaseModel):
    student_id: str | None = None
    name: str | None = None
    branch_id: int | None = None
    batch: int | None = None
    email: str | None = None
    program: str | None = None


class StudentResponse(BaseModel):
    student_id: str
    name: str
    branch_id: int
    batch: int | None = None
    email: str | None = None
    program: str

    model_config = {"from_attributes": True}

class StudentBulkDelete(BaseModel):
    student_ids: list[str]

class StudentBulkUpdate(BaseModel):
    student_ids: list[str]
    branch_id: int | None = None
    batch: int | None = None
    program: str | None = None