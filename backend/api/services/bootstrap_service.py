from sqlalchemy.orm import Session
from backend.database.models.slot import SlotModel
from backend.api.services.slot_service import configure_slots
from backend.api.schemas.slot_schema import SlotConfigureRequest

from backend.database.models.session import SessionModel
from backend.database.models.timetable_conflict_type import TimetableConflictTypeModel


# ── Canonical conflict-type definitions (ID → name, weight) ──
CONFLICT_TYPE_SEED = [
    (1,  "Lunch Break Conflict",   100_000),
    (2,  "Same-Day Duplicate",     1_000),
    (3,  "Missing Enrollments",    1_000),
    (4,  "Day Boundary Conflict",  500),
    (5,  "Invalid Timeslot",       100),
    (6,  "Teacher Overlap",        10),
    (7,  "Room Overlap",           10),
    (8,  "Group Double-Book",      10),
    (9,  "Student Overlap",        5),
    (10, "Teacher Availability",   1),
    (11, "Room Capacity",          1),
    (12, "Room Type Mismatch",     1),
]

# Quick lookup: constraint key -> type_id  (used by the engine bridge)
CONFLICT_KEY_TO_TYPE_ID = {
    "lunch_break_conflict": 1,
    "same_day_duplicate":   2,
    "missing_enrollments":  3,
    "day_boundary_conflict":4,
    "invalid_timeslot":     5,
    "teacher_conflict":     6,
    "room_conflict":        7,
    "group_conflict":       8,
    "student_overlap":      9,
    "availability":         10,
    "capacity":             11,
    "type_mismatch":        12,
}


def seed_conflict_types(db: Session):
    """Ensure all 12 conflict types are present (idempotent upsert)."""
    for type_id, name, weight in CONFLICT_TYPE_SEED:
        existing = db.query(TimetableConflictTypeModel).filter_by(type_id=type_id).first()
        if not existing:
            db.add(TimetableConflictTypeModel(type_id=type_id, name=name, weight=weight))
        else:
            existing.name = name
            existing.weight = weight
    db.commit()


def bootstrap_central_database(db: Session):
    """
    Ensures the Central Database (-1) and its valid starting configuration
    exist if the database was recently reset.
    """
    # 0. Seed conflict types (always — idempotent)
    seed_conflict_types(db)

    # 1. Ensure the 'Central Database' record exists in session_table
    central_session = db.query(SessionModel).filter_by(session_id=-1).first()
    if not central_session:
        print("Creating Central Database session record...")
        db.add(SessionModel(session_id=-1, name="Central Database", is_active=True))
        db.commit()

    # 2. Check if ANY slots exist for Central Database
    exists = db.query(SlotModel).filter_by(session_id=-1).first()
    
    if not exists:
        print("Initializing Central Database with default slot configuration...")
        
        # 2. Prepare default configuration
        # 9:00 AM - 6:00 PM (18:00)
        # Monday - Saturday
        # Lunch (13:00) is automatically handled by the UI/Service if blocked
        
        default_config = SlotConfigureRequest(
            start_hour=9,
            end_hour=18,
            working_days=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
            blocked_slots=[] # The service handles Lunch (13:00) as a forced block if we want, 
                             # or we can explicitly block it here for clarity.
        )
        
        # Explicitly block Lunch (Period 5 for 9-18 range)
        # Period 1: 9:00, 2: 10:00, 3: 11:00, 4: 12:00, 5: 13:00
        from backend.api.schemas.slot_schema import BlockedSlot
        default_config.blocked_slots.append(BlockedSlot(day="Monday", period=5))
        default_config.blocked_slots.append(BlockedSlot(day="Tuesday", period=5))
        default_config.blocked_slots.append(BlockedSlot(day="Wednesday", period=5))
        default_config.blocked_slots.append(BlockedSlot(day="Thursday", period=5))
        default_config.blocked_slots.append(BlockedSlot(day="Friday", period=5))
        default_config.blocked_slots.append(BlockedSlot(day="Saturday", period=5))
        
        try:
            configure_slots(db, default_config, session_id=-1)
            print("Central Database initialized successfully.")
        except Exception as e:
            print(f"Failed to bootstrap Central Database: {e}")
    else:
        # Already initialized, skip
        pass
