from pydantic import BaseModel
from typing import Optional

class SessionSchema(BaseModel):
    session_id: int
    name: str
    is_active: bool

class SessionCreate(BaseModel):
    name: str
    is_active: Optional[bool] = True

class SessionUpdate(BaseModel):
    name: str
