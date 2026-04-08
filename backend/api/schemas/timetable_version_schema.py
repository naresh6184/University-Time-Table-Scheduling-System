from pydantic import BaseModel
from typing import List, Optional

class TimetableVersionSchema(BaseModel):
    session_id: int
    version_id: int
    population_size: int
    generations: int
    best_violation: int
    best_soft_score: float
    is_active: bool
    conflict_json: Optional[str] = None

class TimetableVersionListResponse(BaseModel):
    versions: List[TimetableVersionSchema]
