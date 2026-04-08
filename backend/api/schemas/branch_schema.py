from pydantic import BaseModel


class BranchCreate(BaseModel):
    name: str
    abbreviation: str | None = None


class BranchUpdate(BaseModel):
    name: str | None = None
    abbreviation: str | None = None


class BranchResponse(BaseModel):
    branch_id: int
    name: str
    abbreviation: str | None = None


    model_config = {"from_attributes": True}