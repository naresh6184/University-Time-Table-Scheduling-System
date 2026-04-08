import uvicorn
import sys
import os
from multiprocessing import freeze_support

# Ensure backend folder is in path if running as script
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backend.api.main import app

if __name__ == "__main__":
    # Required for PyInstaller support on Windows
    freeze_support()
    
    # --- CONFIGURE UVICORN TO LOG TO FILE ---
    import logging
    from backend.database.config import file_handler
    
    # Add our file handler to uvicorn loggers
    for logger_name in ["uvicorn", "uvicorn.access", "uvicorn.error"]:
        u_logger = logging.getLogger(logger_name)
        u_logger.addHandler(file_handler)
        u_logger.propagate = False # Prevent double logging to stdout
    
    # Run the server
    uvicorn.run(
        app, 
        host="127.0.0.1", 
        port=8000, 
        log_level="info",
        log_config=None, # Use our logging config
        workers=1
    )
