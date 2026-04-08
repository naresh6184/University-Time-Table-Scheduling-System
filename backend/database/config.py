import os
import sys
import logging
from dotenv import load_dotenv
from pathlib import Path

# Determine the base directory (where the EXE or main script is)
if getattr(sys, 'frozen', False):
    # If running as a bundled executable
    base_dir = Path(sys.executable).parent
else:
    # If running as a standard script
    base_dir = Path(__file__).resolve().parent.parent.parent

# --- CONFIGURE LOGGING TO FILE ---
log_file = base_dir / "server.log"
file_handler = logging.FileHandler(log_file, mode="a", encoding="utf-8")
file_handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))

logging.basicConfig(
    level=logging.INFO,
    handlers=[
        file_handler,
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("backend")
logger.info(f"LOGGING INITIALIZED: Writing to {log_file}")

# 1. Try to load from .env (check both base_dir and exe_dir if frozen)
env_path = base_dir / ".env"
if not env_path.exists() and getattr(sys, 'frozen', False):
    env_path = Path(sys.executable).parent / ".env"
load_dotenv(env_path)

# 2. Build a stable SQLite path if no DATABASE_URL is set
# We default to the application folder to keep everything in one place (C:\UniScheduler)
# IMPORTANT: Use forward slashes for SQLAlchemy URLs on Windows
db_path_obj = base_dir / 'app_db.sqlite'

# Ensure the parent directory exists (e.g., C:\UniScheduler)
# This prevents SQLite from failing if the folder is missing.
try:
    if not db_path_obj.parent.exists():
        os.makedirs(db_path_obj.parent, exist_ok=True)
except Exception:
    pass # Fallback to local if permissions fail

db_path = db_path_obj.as_posix()
default_sqlite_path = f"sqlite:///{db_path}"

DATABASE_URL = os.getenv("DATABASE_URL", default_sqlite_path)

# Verbose logging to help debug environment issues
print(f"DATABASE CONFIG: Using DB at {db_path_obj.absolute()}")