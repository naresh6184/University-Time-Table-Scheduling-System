from pydantic import BaseModel

class ClassroomCreate(BaseModel):
    name: str
    capacity: int
    room_type: str

class ClassroomUpdate(BaseModel):
    name: str | None = None
    capacity: int | None = None
    room_type: str | None = None

class ClassroomResponse(BaseModel):
    room_id: int
    name: str
    capacity: int
    room_type: str

    model_config = {"from_attributes": True}