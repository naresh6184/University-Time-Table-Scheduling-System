from pydantic import BaseModel

class TeacherCreate(BaseModel):
    name: str
    code: str
    email: str | None = None

class TeacherUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    email: str | None = None

class TeacherResponse(BaseModel):
    teacher_id: int
    name: str
    code: str
    email: str | None = None


    model_config = {"from_attributes": True}