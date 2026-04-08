from pydantic import BaseModel


class GroupCreate(BaseModel):
    name: str
    description: str | None = None
    program: str | None = 'B.Tech'
    batch: int | None = None
    branch_id: int | None = None


class GroupUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    program: str | None = None
    batch: int | None = None
    branch_id: int | None = None


class GroupResponse(BaseModel):
    group_id: int
    name: str
    description: str | None = None
    program: str | None = None
    batch: int | None = None
    branch_id: int | None = None
    student_count: int = 0

    model_config = {"from_attributes": True}