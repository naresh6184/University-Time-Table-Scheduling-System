from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker, declarative_base
from backend.database.config import DATABASE_URL
from sqlalchemy.engine.url import make_url
from sqlalchemy.pool import NullPool
import logging as _logging

is_sqlite = DATABASE_URL.startswith("sqlite")

def init_sqlite_database():
    """
    Initializes the SQLite database with WAL mode.
    Call this during application startup (e.g., in lifespan).
    """
    if not is_sqlite:
        return
        
    _sqlite_logger = _logging.getLogger("backend")
    try:
        import sqlite3
        # Ensure we have a clean path for sqlite3.connect
        _db_path = DATABASE_URL.replace("sqlite:///", "")
        
        _sqlite_logger.info(f"SQLITE: Initializing WAL mode for {_db_path}")
        _raw_conn = sqlite3.connect(_db_path)
        _raw_conn.execute("PRAGMA journal_mode=WAL")
        _raw_conn.execute("PRAGMA synchronous=NORMAL")
        _raw_conn.close()
        _sqlite_logger.info("SQLITE: WAL mode enabled successfully")
    except Exception as _e:
        _sqlite_logger.warning(f"SQLITE: Failed to set WAL mode: {_e}")

if not is_sqlite:
    def create_database_if_not_exists(url: str):
        parsed_url = make_url(url)
        db_name = parsed_url.database
        if not db_name:
            return
        
        server_url = parsed_url.set(database='')
        temp_engine = create_engine(server_url)
        with temp_engine.connect() as conn:
            conn.execute(text(f"CREATE DATABASE IF NOT EXISTS {db_name}"))
            conn.commit()
        temp_engine.dispose()

    create_database_if_not_exists(DATABASE_URL)

if is_sqlite:
    # --- Engine: Use NullPool for SQLite on Windows to avoid locking issues ---
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False, "timeout": 30},
        poolclass=NullPool
    )
    
    # Per-connection: lightweight pragmas only
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_con, connection_record):
        cursor = dbapi_con.cursor()
        cursor.execute("PRAGMA busy_timeout=60000")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()
else:
    engine = create_engine(
        DATABASE_URL,
        pool_recycle=3600,       # Recycle connections every hour
        pool_pre_ping=True,      # Check connection health before use
        connect_args={
            "connect_timeout": 10,  # Fail fast if can't connect
        }
    )

    # Set lock_wait_timeout per connection so hung queries fail in 10s
    @event.listens_for(engine, "connect")
    def set_lock_timeout(dbapi_con, connection_record):
        cursor = dbapi_con.cursor()
        cursor.execute("SET SESSION lock_wait_timeout = 10")
        cursor.execute("SET SESSION innodb_lock_wait_timeout = 10")
        cursor.close()

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()


from sqlalchemy.orm import Session
from typing import Generator


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
