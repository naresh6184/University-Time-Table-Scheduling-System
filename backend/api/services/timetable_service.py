from sqlalchemy.orm import Session
from backend.api.services.timetable_queries import (
    get_group_grid_rows,
    get_teacher_grid_rows,
    get_room_grid_rows,
    get_branch_grid_rows,
    get_timetable_versions,
    detect_conflicts,
    get_all_timetable_entries,
    get_all_slots,
    get_resolved_version,
    activate_timetable_version,
    delete_timetable_version,
    reset_database
)
from backend.api.utils.timetable_utils import convert_to_grid
from backend.bridge.runner import run_scheduler
from backend.database.models import (
    BranchModel,
    StudentModel,
    GroupModel,
    GroupStudentModel,
    TeacherModel,
    ClassroomModel,
    SubjectModel,
    EnrollmentModel,
    SlotModel,
    TimetableVersionModel,
    TimetableEntryModel
)


def get_group_grid(db: Session, group_id: int, version_id: int = None):

    rows = get_group_grid_rows(db, group_id, version_id)
    active_version = get_resolved_version(db, version_id)
    session_id = active_version.session_id if active_version else -1
    slots = get_all_slots(db, session_id=session_id)

    grid = convert_to_grid(rows, slots, context="group")
    assignments = set()
    for r in rows:
        subj_abbr = getattr(r, "subject_abbreviation", None) or getattr(r, "subject_code", None) or getattr(r, "subject_name", "")
        subj_name = getattr(r, "subject_name", "")
        teach_abbr = getattr(r, "teacher_code", None) or getattr(r, "teacher_name", "")
        teach_name = getattr(r, "teacher_name", "")
        assignments.add((subj_abbr, subj_name, teach_abbr, teach_name))

    periods = build_period_metadata(slots)

    return {
        "group_id": group_id,
        "periods": periods,
        "grid": grid,
        "assignments": list(assignments)
    }


def get_teacher_grid(db: Session, teacher_id: int, version_id: int = None):

    rows = get_teacher_grid_rows(db, teacher_id, version_id)
    active_version = get_resolved_version(db, version_id)
    session_id = active_version.session_id if active_version else -1
    slots = get_all_slots(db, session_id=session_id)

    grid = convert_to_grid(rows, slots, context="teacher")
    assignments = set()
    for r in rows:
        subj_abbr = getattr(r, "subject_abbreviation", None) or getattr(r, "subject_code", None) or getattr(r, "subject_name", "")
        subj_name = getattr(r, "subject_name", "")
        teach_abbr = getattr(r, "teacher_code", None) or getattr(r, "teacher_name", "")
        teach_name = getattr(r, "teacher_name", "")
        assignments.add((subj_abbr, subj_name, teach_abbr, teach_name))

    periods = build_period_metadata(slots)

    return {
        "teacher_id": teacher_id,
        "periods": periods,
        "grid": grid,
        "assignments": list(assignments)
    }


def get_room_grid(db: Session, room_id: int, version_id: int = None):

    rows = get_room_grid_rows(db, room_id, version_id)
    active_version = get_resolved_version(db, version_id)
    session_id = active_version.session_id if active_version else -1
    slots = get_all_slots(db, session_id=session_id)

    grid = convert_to_grid(rows, slots, context="room")
    assignments = set()
    for r in rows:
        subj_abbr = getattr(r, "subject_abbreviation", None) or getattr(r, "subject_code", None) or getattr(r, "subject_name", "")
        subj_name = getattr(r, "subject_name", "")
        teach_abbr = getattr(r, "teacher_code", None) or getattr(r, "teacher_name", "")
        teach_name = getattr(r, "teacher_name", "")
        assignments.add((subj_abbr, subj_name, teach_abbr, teach_name))

    periods = build_period_metadata(slots)

    return {
        "room_id": room_id,
        "periods": periods,
        "grid": grid,
        "assignments": list(assignments)
    }

def list_versions(db: Session, session_id: int):

    versions = get_timetable_versions(db, session_id)

    return {
        "versions": versions
    }



def activate_version(db: Session, version_id: int):

    version = activate_timetable_version(db, version_id)

    if not version:
        return {
            "status": "error",
            "message": "Version not found"
        }

    return {
        "status": "success",
        "activated_version": version_id
    }



def get_conflicts(db: Session, version_id: int = None):

    teacher_conflicts, room_conflicts, group_conflicts = detect_conflicts(db, version_id)

    return {
        "teacher_conflicts": [
            {
                "teacher_id": c.teacher_id,
                "slot_id": c.slot_id
            }
            for c in teacher_conflicts
        ],
        "room_conflicts": [
            {
                "room_id": c.room_id,
                "slot_id": c.slot_id
            }
            for c in room_conflicts
        ],
        "group_conflicts": [
            {
                "group_id": c.group_id,
                "slot_id": c.slot_id
            }
            for c in group_conflicts
        ]
    }



def get_institute_timetable(db: Session, session_id: int):

    rows = get_all_timetable_entries(db, session_id)
    slots = get_all_slots(db)

    groups = {}
    teachers = {}
    rooms = {}

    for r in rows:
        groups.setdefault(r.group_id, []).append(r)
        teachers.setdefault(r.teacher_id, []).append(r)
        rooms.setdefault(r.room_id, []).append(r)

    group_grids = {
        gid: convert_to_grid(entries, slots)
        for gid, entries in groups.items()
    }

    teacher_grids = {
        tid: convert_to_grid(entries, slots)
        for tid, entries in teachers.items()
    }

    room_grids = {
        rid: convert_to_grid(entries, slots)
        for rid, entries in rooms.items()
    }

    # build periods metadata
    periods = [
        {
            "period": s.period_number,
            "start": s.start_time,
            "end": s.end_time
        }
        for s in slots if s.day == "Monday"
    ]

    return {
        "periods": periods,   
        "groups": group_grids,
        "teachers": teacher_grids,
        "rooms": room_grids
    }

def get_slots(db: Session):

    rows = get_all_slots(db)

    slots = []

    for r in rows:
        slots.append({
            "slot_id": r.slot_id,
            "day": r.day,
            "period_number": r.period_number,
            "start_time": r.start_time,
            "end_time": r.end_time
        })

    return {
        "slots": slots
    }
    

def reset_system(db: Session, session_id: int):

    reset_database(db, session_id)
    return {
        "message": f"Session {session_id} reset complete"
    }


# Helper function to add period metadata
def build_period_metadata(slots):

    periods = {}

    for s in slots:

        if s.period_number not in periods:
            periods[s.period_number] = {
                "period": s.period_number,
                "start": s.start_time,
                "end": s.end_time
            }

    return sorted(periods.values(), key=lambda x: x["period"])

def get_branch_grid(db: Session, branch_id: int, version_id: int = None):
    rows = get_branch_grid_rows(db, branch_id, version_id)
    slots = get_all_slots(db)

    grid = convert_to_grid(rows, slots, context="branch")
    assignments = set()
    for r in rows:
        subj_abbr = getattr(r, "subject_abbreviation", None) or getattr(r, "subject_code", None) or getattr(r, "subject_name", "")
        subj_name = getattr(r, "subject_name", "")
        teach_abbr = getattr(r, "teacher_code", None) or getattr(r, "teacher_name", "")
        teach_name = getattr(r, "teacher_name", "")
        assignments.add((subj_abbr, subj_name, teach_abbr, teach_name))

    periods = build_period_metadata(slots)

    return {
        "branch_id": branch_id,
        "periods": periods,
        "grid": grid,
        "assignments": list(assignments)
    }