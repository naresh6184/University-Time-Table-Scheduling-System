from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from pydantic import BaseModel
from typing import Any, Dict, List

from backend.database.session import get_db

router = APIRouter(
    prefix="/admin/sql",
    tags=["Admin - SQL Console"]
)

class SQLQueryRequest(BaseModel):
    query: str
    password: str

class SQLQueryResponse(BaseModel):
    success: bool
    is_select: bool
    columns: List[str] = []
    rows: List[Dict[str, Any]] = []
    rows_affected: int = 0
    message: str = ""

class SQLVerifyRequest(BaseModel):
    password: str

@router.post("/verify")
def verify_password(request: SQLVerifyRequest):
    import hashlib
    expected_hash = "e34f92a20532a873cb3184398070b4b82a8fa29cf48572c203dc5f0fa6158231"
    provided_hash = hashlib.sha256(request.password.encode('utf-8')).hexdigest()
    
    if provided_hash != expected_hash:
        raise HTTPException(status_code=403, detail="Unauthorized: Invalid developer password.")
    return {"success": True}

@router.post("/execute", response_model=SQLQueryResponse)
def execute_sql(request: SQLQueryRequest, db: Session = Depends(get_db)):
    import hashlib
    
    # We use a SHA-256 hash so the plaintext password is NOT on GitHub, 
    # AND end-users cannot simply change a .env file to gain access to the database.
    # The developer password is: superadmin123
    expected_hash = "e34f92a20532a873cb3184398070b4b82a8fa29cf48572c203dc5f0fa6158231"
    
    provided_hash = hashlib.sha256(request.password.encode('utf-8')).hexdigest()
    
    if provided_hash != expected_hash:
        raise HTTPException(status_code=403, detail="Unauthorized: Invalid developer password.")

    query_str = request.query.strip()
    if not query_str:
        raise HTTPException(status_code=400, detail="Query cannot be empty.")

    # Convert common MySQL syntax to SQLite syntax for better UX
    upper_query = query_str.upper()
    if upper_query == "SHOW TABLES;" or upper_query == "SHOW TABLES":
        query_str = "SELECT name as table_name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    elif upper_query.startswith("DESCRIBE ") or upper_query.startswith("DESC "):
        import re
        # Extract the table name
        match = re.search(r'DESC(?:RIBE)?\s+([a-zA-Z0-9_]+)', query_str, re.IGNORECASE)
        if match:
            table_name = match.group(1)
            query_str = f"PRAGMA table_info('{table_name}');"

    try:
        # We use text() to execute raw SQL.
        result = db.execute(text(query_str))
        
        # Determine if it's a SELECT-like query that returns rows
        if result.returns_rows:
            rows = result.fetchall()
            columns = list(result.keys())
            
            # Convert rows to a list of dicts
            data = []
            for row in rows:
                row_dict = {}
                for idx, col in enumerate(columns):
                    row_dict[col] = row[idx]
                data.append(row_dict)
                
            return SQLQueryResponse(
                success=True,
                is_select=True,
                columns=columns,
                rows=data,
                rows_affected=len(data),
                message=f"Returned {len(data)} rows."
            )
        else:
            # It's an UPDATE, INSERT, DELETE, etc.
            db.commit()
            rows_affected = result.rowcount
            return SQLQueryResponse(
                success=True,
                is_select=False,
                rows_affected=rows_affected,
                message=f"Query executed successfully. Rows affected: {rows_affected}"
            )
            
    except SQLAlchemyError as e:
        db.rollback()
        # Extract the specific database error message
        error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
        raise HTTPException(status_code=400, detail=f"SQL Error: {error_msg}")
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Unexpected Error: {str(e)}")
