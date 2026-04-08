from sqlalchemy.orm import Session
from backend.database.models.timetable_version import TimetableVersionModel
from backend.database.models.timetable_entry import TimetableEntryModel

def convert_to_grid(entries, slots, context=None):

    if not slots:
        return {}

    # --------------------------------
    # Build per-day sorted period lists and contiguous index maps
    # --------------------------------
    day_periods = {}  # day -> sorted list of period_numbers
    for s in slots:
        day_periods.setdefault(s.day, set()).add(s.period_number)
    for day in day_periods:
        day_periods[day] = sorted(day_periods[day])

    # Map: (day, period_number) -> contiguous 0-based index
    period_to_idx = {}
    for day, periods in day_periods.items():
        for idx, pnum in enumerate(periods):
            period_to_idx[(day, pnum)] = idx

    # --------------------------------
    # Build slot lookup: slot_id -> (day, period_number)
    # --------------------------------
    slot_lookup = {
        s.slot_id: (s.day, s.period_number)
        for s in slots
    }

    # --------------------------------
    # Find unique days and grid size per day
    # --------------------------------
    days = sorted({s.day for s in slots})
    num_columns = max(len(day_periods[d]) for d in days)

    # --------------------------------
    # Initialize empty grid (contiguous columns, no gaps)
    # --------------------------------
    grid = {
        day: [None] * len(day_periods[day])
        for day in days
    }

    # --------------------------------
    # Fill timetable entries
    # --------------------------------
    for e in entries:

        slot_id = getattr(e, "slot_id", None)

        if slot_id not in slot_lookup:
            continue

        day, period = slot_lookup[slot_id]

        subject_name = getattr(e, "subject_name", None)
        subject_code = getattr(e, "subject_code", None)
        subject_abbreviation = getattr(e, "subject_abbreviation", None)
        group = getattr(e, "group_name", None)
        teacher_name = getattr(e, "teacher_name", None)
        teacher_code = getattr(e, "teacher_code", None)
        room = getattr(e, "room_id", None)
        room_name = getattr(e, "room_name", None)
        duration = getattr(e, "duration", 1) or 1
        enrollment_id = getattr(e, "enrollment_id", None)

        cell = {
            "subject": subject_abbreviation or subject_code or subject_name,
            "duration": duration,
            "isContinuation": False,
            "enrollmentId": enrollment_id,
            "entryId": getattr(e, "entry_id", None),
        }

        # Always include all entities so conflict relevance checks work in all views
        cell["group"] = group
        cell["teacher"] = teacher_code or teacher_name
        cell["room"] = room_name or f"Room #{room}"


        # Place at contiguous index — stack if slot is already occupied
        # Place at contiguous index — stack if slot is already occupied
        # PRIORITIZATION: 
        # 1. Start cells (non-continuation) should ALWAYS be primary over Continuation cells.
        # 2. Between multiple Start cells, the LONGEST session (by duration) should be primary
        #    so its full span is visible in the UI.
        start_idx = period_to_idx.get((day, period))
        if start_idx is not None:
            if grid[day][start_idx] is None:
                grid[day][start_idx] = cell
            else:
                existing = grid[day][start_idx]
                is_exist_cont = existing.get('isContinuation', False)
                is_new_cont = cell.get('isContinuation', False)
                
                # Logic: Swap if the new cell is "more important" than the existing one
                #   - Non-continuation is more important than continuation
                #   - Longer duration is more important than shorter duration (if both are non-continuation)
                should_swap = False
                if is_exist_cont and not is_new_cont:
                    should_swap = True
                elif not is_exist_cont and not is_new_cont:
                    if cell.get('duration', 1) > existing.get('duration', 1):
                        should_swap = True

                if should_swap:
                    # Swap: current cell becomes primary, existing goes to stack
                    grid[day][start_idx] = cell
                    if "stackedEntries" not in cell:
                        cell["stackedEntries"] = []
                    cell["stackedEntries"].append(existing)
                    # Move previous stack too
                    if "stackedEntries" in existing:
                        cell["stackedEntries"].extend(existing.pop("stackedEntries"))
                else:
                    # Normal stacking: add current to existing stack
                    if "stackedEntries" not in existing:
                        existing["stackedEntries"] = []
                    existing["stackedEntries"].append(cell)

        # Fill consecutive periods for multi-hour sessions
        sorted_periods = day_periods[day]
        for offset in range(1, duration):
            next_idx = start_idx + offset
            if next_idx < len(sorted_periods):
                cont_cell = dict(cell)
                cont_cell["isContinuation"] = True
                
                if grid[day][next_idx] is None:
                    grid[day][next_idx] = cont_cell
                else:
                    existing = grid[day][next_idx]
                    # Continuation cells always stack unless they are more important? 
                    # No, if a Start cell is at next_idx, it should stay primary.
                    if "stackedEntries" not in existing:
                        existing["stackedEntries"] = []
                    existing["stackedEntries"].append(cont_cell)

    return grid

def detect_duplicate_version(db: Session, session_id: int, new_version_id: int):
    # Get the mapping for the newly generated version
    new_entries = db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id == new_version_id).all()
    if not new_entries:
        return None
        
    new_mapping = {(e.enrollment_id, e.slot_id, e.room_id) for e in new_entries}
    
    # Query all other versions in the same session, excluding the new one
    other_versions = db.query(TimetableVersionModel).filter(
        TimetableVersionModel.session_id == session_id,
        TimetableVersionModel.version_id != new_version_id
    ).order_by(TimetableVersionModel.version_id.desc()).all()
    
    for v in other_versions:
        # Optimization: only check versions with identical total entries if there were an optimization, but sets handle mismatches anyway
        other_entries = db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id == v.version_id).all()
        other_mapping = {(e.enrollment_id, e.slot_id, e.room_id) for e in other_entries}
        
        # Exact identical mapping found
        if new_mapping == other_mapping:
            return v.version_id
            
    return None