from pydantic import BaseModel


class GroupStudentCreate(BaseModel):
    group_id: int
    student_id: str

class BulkAddRequest(BaseModel):
    target_group_id: int
    student_ids: list[str]

class BulkRemoveRequest(BaseModel):
    target_group_id: int
    student_ids: list[str]