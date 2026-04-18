from sqlalchemy.orm import Session
from sqlalchemy import func

from backend.database.models.timetable_version import TimetableVersionModel
from backend.database.models.timetable_entry import TimetableEntryModel

from backend.database.models import (
    StudentModel,
    GroupModel,
    GroupStudentModel,
    ClassroomModel,
    SubjectModel,
    EnrollmentModel,
    SlotModel,
    BranchModel,
    TeacherModel
)
from backend.database.models.teacher_availability import SessionTeacherAvailabilityModel
from backend.database.models.session_slot import SessionSlotModel


# ------------------------------------------------
# Helper: Get active timetable version
# ------------------------------------------------
def get_active_version(db: Session, session_id: int = None):
    q = db.query(TimetableVersionModel).filter(TimetableVersionModel.is_active == True)
    if session_id:
        q = q.filter(TimetableVersionModel.session_id == session_id)
    return q.order_by(TimetableVersionModel.version_id.desc()).first()

def get_resolved_version(db: Session, version_id: int = None, session_id: int = None):
    if version_id:
        version = db.query(TimetableVersionModel).filter(TimetableVersionModel.version_id == version_id).first()
    else:
        version = get_active_version(db, session_id)
        
    if version and version.is_duplicate_of:
        # Resolve pointer to the actual data source
        return db.query(TimetableVersionModel).filter(TimetableVersionModel.version_id == version.is_duplicate_of).first()
    return version


# ------------------------------------------------
# Branch timetable
# ------------------------------------------------
def get_branch_timetable(db: Session, branch_id: int, version_id: int = None):

    active_version = get_resolved_version(db, version_id)

    if not active_version:
        return []

    entries = (
        db.query(TimetableEntryModel)
        .join(
            EnrollmentModel,
            TimetableEntryModel.enrollment_id == EnrollmentModel.enrollment_id
        )
        .join(
            GroupStudentModel,
            EnrollmentModel.group_id == GroupStudentModel.group_id
        )
        .join(
            StudentModel,
            GroupStudentModel.student_id == StudentModel.student_id
        )
        .filter(
            StudentModel.branch_id == branch_id,
            TimetableEntryModel.version_id == active_version.version_id
        )
        .all()
    )

    return entries


# ------------------------------------------------
# Teacher timetable
# ------------------------------------------------
def get_teacher_timetable(db: Session, teacher_id: int, version_id: int = None):

    active_version = get_resolved_version(db, version_id)

    if not active_version:
        return []

    rows = (
        db.query(
            TimetableEntryModel.slot_id,
            SubjectModel.name.label("subject_name"),
            SubjectModel.code.label("subject_code"),
            GroupModel.name.label("group_name"),
            ClassroomModel.room_id,
            ClassroomModel.room_type
        )
        .join(
            EnrollmentModel,
            EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
        )
        .join(
            SubjectModel,
            SubjectModel.subject_id == EnrollmentModel.subject_id
        )
        .outerjoin(
            ClassroomModel,
            ClassroomModel.room_id == TimetableEntryModel.room_id
        )
        .outerjoin(
            GroupModel,
            GroupModel.group_id == EnrollmentModel.group_id
        )
        .filter(
            EnrollmentModel.teacher_id == teacher_id,
            TimetableEntryModel.version_id == active_version.version_id
        )
        .all()
    )

    return rows


# ------------------------------------------------
# Group timetable
# ------------------------------------------------
def get_group_timetable(db: Session, group_id: int, version_id: int = None):

    active_version = get_resolved_version(db, version_id)

    if not active_version:
        return []

    rows = (
        db.query(
            TimetableEntryModel.slot_id,
            SubjectModel.name.label("subject_name"),
            SubjectModel.code.label("subject_code"),
            EnrollmentModel.teacher_id,
            ClassroomModel.room_id,
            ClassroomModel.room_type
        )
        .join(
            EnrollmentModel,
            EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
        )
        .join(
            SubjectModel,
            SubjectModel.subject_id == EnrollmentModel.subject_id
        )
        .outerjoin(
            ClassroomModel,
            ClassroomModel.room_id == TimetableEntryModel.room_id
        )
        .filter(
            EnrollmentModel.group_id == group_id,
            TimetableEntryModel.version_id == active_version.version_id
        )
        .all()
    )

    return rows


# ------------------------------------------------
# Room timetable
# ------------------------------------------------
def get_room_timetable(db: Session, room_id: int, version_id: int = None):

    active_version = get_resolved_version(db, version_id)

    if not active_version:
        return []

    rows = (
        db.query(
            TimetableEntryModel.slot_id,
            SubjectModel.name.label("subject_name"),
            SubjectModel.code.label("subject_code"),
            GroupModel.name.label("group_name"),
            TeacherModel.name.label("teacher_name"),
            TeacherModel.code.label("teacher_code")
        )
        .join(
            EnrollmentModel,
            EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
        )
        .join(
            SubjectModel,
            SubjectModel.subject_id == EnrollmentModel.subject_id
        )
        .outerjoin(
            TeacherModel,
            TeacherModel.teacher_id == EnrollmentModel.teacher_id
        )
        .outerjoin(
            GroupModel,
            GroupModel.group_id == EnrollmentModel.group_id
        )
        .filter(
            TimetableEntryModel.room_id == room_id,
            TimetableEntryModel.version_id == active_version.version_id
        )
        .all()
    )

    return rows


# ------------------------------------------------
# Group grid rows
# ------------------------------------------------
def get_group_grid_rows(db: Session, group_id: int, version_id: int = None):

    active_version = get_resolved_version(db, version_id)

    if not active_version:
        return []

    rows = (
        db.query(
            TimetableEntryModel.entry_id,
            TimetableEntryModel.slot_id,
            TimetableEntryModel.duration,
            TimetableEntryModel.enrollment_id,
            SubjectModel.name.label("subject_name"),
            SubjectModel.code.label("subject_code"),
            SubjectModel.abbreviation.label("subject_abbreviation"),
            GroupModel.name.label("group_name"),
            TeacherModel.name.label("teacher_name"),
            TeacherModel.code.label("teacher_code"),
            ClassroomModel.room_id,
            ClassroomModel.name.label("room_name")
        )
        .join(
            EnrollmentModel,
            EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
        )
        .join(
            TeacherModel,
            TeacherModel.teacher_id == EnrollmentModel.teacher_id
        )
        .join(
            SubjectModel,
            SubjectModel.subject_id == EnrollmentModel.subject_id
        )
        .join(
            GroupModel,
            GroupModel.group_id == EnrollmentModel.group_id
        )
        .join(
            ClassroomModel,
            ClassroomModel.room_id == TimetableEntryModel.room_id
        )
        .filter(
            EnrollmentModel.group_id == group_id,
            TimetableEntryModel.version_id == active_version.version_id
        )
        .all()
    )

    return rows


# ------------------------------------------------
# Teacher grid rows
# ------------------------------------------------
def get_teacher_grid_rows(db: Session, teacher_id: int, version_id: int = None):

    active_version = get_resolved_version(db, version_id)

    if not active_version:
        return []

    rows = (
        db.query(
            TimetableEntryModel.entry_id,
            TimetableEntryModel.slot_id,
            TimetableEntryModel.duration,
            TimetableEntryModel.enrollment_id,
            SubjectModel.name.label("subject_name"),
            SubjectModel.code.label("subject_code"),
            SubjectModel.abbreviation.label("subject_abbreviation"),
            GroupModel.name.label("group_name"),
            TeacherModel.name.label("teacher_name"),
            TeacherModel.code.label("teacher_code"),
            ClassroomModel.room_id,
            ClassroomModel.name.label("room_name")
        )
        .join(
            EnrollmentModel,
            EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
        )
        .join(
            TeacherModel,
            TeacherModel.teacher_id == EnrollmentModel.teacher_id
        )
        .join(
            SubjectModel,
            SubjectModel.subject_id == EnrollmentModel.subject_id
        )
        .join(
            GroupModel,
            GroupModel.group_id == EnrollmentModel.group_id
        )
        .join(
            ClassroomModel,
            ClassroomModel.room_id == TimetableEntryModel.room_id
        )
        .filter(
            EnrollmentModel.teacher_id == teacher_id,
            TimetableEntryModel.version_id == active_version.version_id
        )
        .all()
    )

    return rows


# ------------------------------------------------
# Room grid rows
# ------------------------------------------------
def get_room_grid_rows(db: Session, room_id: int, version_id: int = None):

    active_version = get_resolved_version(db, version_id)

    if not active_version:
        return []

    rows = (
        db.query(
            TimetableEntryModel.entry_id,
            TimetableEntryModel.slot_id,
            TimetableEntryModel.duration,
            TimetableEntryModel.enrollment_id,
            SubjectModel.name.label("subject_name"),
            SubjectModel.code.label("subject_code"),
            SubjectModel.abbreviation.label("subject_abbreviation"),
            GroupModel.name.label("group_name"),
            TeacherModel.name.label("teacher_name"),
            ClassroomModel.room_id.label("room_id"),
            ClassroomModel.name.label("room_name")
        )
        .join(
            EnrollmentModel,
            EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
        )
        .join(
            TeacherModel,
            TeacherModel.teacher_id == EnrollmentModel.teacher_id
        )
        .join(
            SubjectModel,
            SubjectModel.subject_id == EnrollmentModel.subject_id
        )
        .join(
            GroupModel,
            GroupModel.group_id == EnrollmentModel.group_id
        )
        .join(
            ClassroomModel,
            ClassroomModel.room_id == TimetableEntryModel.room_id
        )
        .filter(
            TimetableEntryModel.room_id == room_id,
            TimetableEntryModel.version_id == active_version.version_id
        )
        .all()
    )

    return rows

# ------------------------------------------------
# Timetable versions
# ------------------------------------------------
def get_timetable_versions(db: Session, session_id: int):

    return db.query(TimetableVersionModel)\
        .filter(TimetableVersionModel.session_id == session_id)\
        .order_by(TimetableVersionModel.version_id.desc())\
        .all()


# ------------------------------------------------
# Activate timetable version
# ------------------------------------------------
def activate_timetable_version(db: Session, version_id: int):

    db.query(TimetableVersionModel).update({"is_active": False})

    version = db.query(TimetableVersionModel)\
        .filter(TimetableVersionModel.version_id == version_id)\
        .first()

    if not version:
        return None

    version.is_active = True
    db.commit()

    return version

# ------------------------------------------------
# Delete a timetable version
# ------------------------------------------------
def delete_timetable_version(db: Session, version_id: int):
    version = db.query(TimetableVersionModel).filter(TimetableVersionModel.version_id == version_id).first()
    if not version:
        return False
        
    db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id == version_id).delete(synchronize_session=False)
    db.delete(version)
    db.commit()
    return True

# ------------------------------------------------
# Mark version as duplicate (keep log, wipe heavy data)
# ------------------------------------------------
def mark_version_as_duplicate(db: Session, version_id: int, duplicate_of_id: int):
    version = db.query(TimetableVersionModel).filter(TimetableVersionModel.version_id == version_id).first()
    if not version:
        return False
        
    # Delete heavy data
    db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id == version_id).delete(synchronize_session=False)
    # Point to older version
    version.is_duplicate_of = duplicate_of_id
    db.commit()
    return True

# ------------------------------------------------
# Conflict detection
# ------------------------------------------------
def detect_conflicts(db: Session, version_id: int = None):

    if version_id:
        active_version = db.query(TimetableVersionModel).filter(TimetableVersionModel.version_id == version_id).first()
    else:
        active_version = get_active_version(db)

    if not active_version:
        return [], [], []

    teacher_conflicts = (
        db.query(
            EnrollmentModel.teacher_id,
            TimetableEntryModel.slot_id,
            func.count().label("count")
        )
        .join(
            EnrollmentModel,
            EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
        )
        .filter(
            TimetableEntryModel.version_id == active_version.version_id
        )
        .group_by(
            EnrollmentModel.teacher_id,
            TimetableEntryModel.slot_id
        )
        .having(func.count() > 1)
        .all()
    )

    room_conflicts = (
        db.query(
            TimetableEntryModel.room_id,
            TimetableEntryModel.slot_id,
            func.count().label("count")
        )
        .filter(
            TimetableEntryModel.version_id == active_version.version_id
        )
        .group_by(
            TimetableEntryModel.room_id,
            TimetableEntryModel.slot_id
        )
        .having(func.count() > 1)
        .all()
    )

    group_conflicts = (
        db.query(
            EnrollmentModel.group_id,
            TimetableEntryModel.slot_id,
            func.count().label("count")
        )
        .join(
            EnrollmentModel,
            EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
        )
        .filter(
            TimetableEntryModel.version_id == active_version.version_id
        )
        .group_by(
            EnrollmentModel.group_id,
            TimetableEntryModel.slot_id
        )
        .having(func.count() > 1)
        .all()
    )

    return teacher_conflicts, room_conflicts, group_conflicts


# ------------------------------------------------
# All timetable entries (for institute view)
# ------------------------------------------------
def get_all_timetable_entries(db: Session, session_id: int):

    active_version = get_active_version(db)

    if not active_version:
        return []

    return db.query(
        TimetableEntryModel.slot_id,
        TimetableEntryModel.duration,
        TimetableEntryModel.room_id,
        EnrollmentModel.teacher_id,
        TeacherModel.name.label("teacher_name"),
        EnrollmentModel.group_id,
        SubjectModel.name.label("subject_name"),
        GroupModel.name.label("group_name")
    )\
    .join(
        EnrollmentModel,
        EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id
    )\
    .join(
        TeacherModel,
        TeacherModel.teacher_id == EnrollmentModel.teacher_id
    )\
    .join(
        SubjectModel,
        SubjectModel.subject_id == EnrollmentModel.subject_id
    )\
    .join(
        GroupModel,
        GroupModel.group_id == EnrollmentModel.group_id
    )\
    .join(
        ClassroomModel,
        ClassroomModel.room_id == TimetableEntryModel.room_id
    )\
    .filter(
        TimetableEntryModel.version_id == active_version.version_id,
        EnrollmentModel.session_id == session_id
    )\
    .all()
    
    

# ------------------------------------------------
# get all slots
# ------------------------------------------------
def get_all_slots(db: Session, session_id: int = -1):
    from backend.database.models.slot import SlotModel
    from backend.database.models.session_slot import SessionSlotModel

    # Use session-scoped slots if session_id is provided, otherwise global
    model = SlotModel if session_id == -1 else SessionSlotModel
    
    return db.query(
        model.slot_id,
        model.day,
        model.period_number,
        model.start_time,
        model.end_time
    ).filter(model.session_id == session_id if hasattr(model, 'session_id') else True)\
     .order_by(model.slot_id).all()
    
# Reset the database   
def reset_database(db: Session, session_id: int):
    from backend.database.models.session_entities import (
        SessionTeacherModel, SessionSubjectModel, SessionGroupModel, SessionClassroomModel
    )

    # Get all version IDs for this session
    version_ids = [v.version_id for v in db.query(TimetableVersionModel).filter(TimetableVersionModel.session_id == session_id).all()]
    
    # Delete entries for those versions
    if version_ids:
        db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id.in_(version_ids)).delete(synchronize_session=False)
    db.query(TimetableVersionModel).filter(TimetableVersionModel.session_id == session_id).delete(synchronize_session=False)

    # Delete enrollments for this session
    db.query(EnrollmentModel).filter(EnrollmentModel.session_id == session_id).delete(synchronize_session=False)

    # Delete session junction table entries (unlink entities from session, don't delete the entities themselves)
    db.query(SessionGroupModel).filter(SessionGroupModel.session_id == session_id).delete(synchronize_session=False)
    db.query(SessionTeacherModel).filter(SessionTeacherModel.session_id == session_id).delete(synchronize_session=False)
    db.query(SessionSubjectModel).filter(SessionSubjectModel.session_id == session_id).delete(synchronize_session=False)
    db.query(SessionClassroomModel).filter(SessionClassroomModel.session_id == session_id).delete(synchronize_session=False)

    # Delete session-scoped slots
    db.query(SessionTeacherAvailabilityModel).filter(
        SessionTeacherAvailabilityModel.slot_id.in_(
            db.query(SessionSlotModel.slot_id).filter(SessionSlotModel.session_id == session_id)
        )
    ).delete(synchronize_session=False)
    
    db.query(SessionSlotModel).filter(SessionSlotModel.session_id == session_id).delete(synchronize_session=False)

    db.commit()

    return True

# ------------------------------------------------
# Active Entities and Branch Grids
# ------------------------------------------------
def get_active_entities(db: Session, session_id: int, version_id: int = None):
    active_version = get_resolved_version(db, version_id, session_id)
    if not active_version:
        return {"groups": [], "teachers": [], "rooms": [], "branches": []}

    # Groups, Teachers, Rooms are straightforward from TimetableEntry/Enrollment
    active_entries_q = db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id == active_version.version_id)
    
    group_ids = [gid for (gid,) in db.query(EnrollmentModel.group_id)
                 .join(TimetableEntryModel, TimetableEntryModel.enrollment_id == EnrollmentModel.enrollment_id)
                 .filter(TimetableEntryModel.version_id == active_version.version_id)
                 .distinct().all()]
                 
    teacher_ids = [tid for (tid,) in db.query(EnrollmentModel.teacher_id)
                   .join(TimetableEntryModel, TimetableEntryModel.enrollment_id == EnrollmentModel.enrollment_id)
                   .filter(TimetableEntryModel.version_id == active_version.version_id)
                   .distinct().all()]
                   
    room_ids = [rid for (rid,) in db.query(TimetableEntryModel.room_id)
                .filter(TimetableEntryModel.version_id == active_version.version_id)
                .distinct().all()]

    # Branches are identified by students in the groups that have lectures
    branch_ids = []
    if group_ids:
        branch_ids = [bid for (bid,) in db.query(StudentModel.branch_id)
                      .join(GroupStudentModel, GroupStudentModel.student_id == StudentModel.student_id)
                      .filter(GroupStudentModel.group_id.in_(group_ids))
                      .distinct().all() if bid is not None]

    return {
        "groups": group_ids,
        "teachers": teacher_ids,
        "rooms": room_ids,
        "branches": branch_ids
    }

def get_branch_grid_rows(db: Session, branch_id: int, version_id: int = None):
    active_version = get_resolved_version(db, version_id, None)
    if not active_version:
        return []

    # Get all group_ids for this branch
    group_ids_query = db.query(GroupStudentModel.group_id).join(StudentModel).filter(StudentModel.branch_id == branch_id).distinct()
    
    rows = (
        db.query(
            TimetableEntryModel.entry_id,
            TimetableEntryModel.slot_id,
            TimetableEntryModel.duration,
            TimetableEntryModel.enrollment_id,
            TimetableEntryModel.room_id,
            EnrollmentModel.subject_id,
            EnrollmentModel.teacher_id,
            EnrollmentModel.group_id,
            SubjectModel.name.label("subject_name"),
            SubjectModel.code.label("subject_code"),
            getattr(SubjectModel, 'abbreviation', SubjectModel.code).label("subject_abbreviation"),
            TeacherModel.name.label("teacher_name"),
            getattr(TeacherModel, 'code', TeacherModel.name).label("teacher_code"),
            ClassroomModel.name.label("room_name"),
            GroupModel.name.label("group_name")
        )
        .select_from(TimetableEntryModel)
        .join(EnrollmentModel, EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id)
        .outerjoin(SubjectModel, SubjectModel.subject_id == EnrollmentModel.subject_id)
        .outerjoin(TeacherModel, TeacherModel.teacher_id == EnrollmentModel.teacher_id)
        .outerjoin(ClassroomModel, ClassroomModel.room_id == TimetableEntryModel.room_id)
        .outerjoin(GroupModel, GroupModel.group_id == EnrollmentModel.group_id)
        .filter(
            EnrollmentModel.group_id.in_(group_ids_query),
            TimetableEntryModel.version_id == active_version.version_id
        )
        .all()
    )

    return rows


# ------------------------------------------------
# Map DB conflict type names -> frontend type names
# ------------------------------------------------
_DB_TYPE_TO_FRONTEND = {
    "Teacher Availability": "Availability",
    "Room Capacity": "Capacity",
    "Room Type Mismatch": "Type Mismatch",
    "Lunch Break Conflict": "Lunch Break Conflict",
    "Same-Day Duplicate": "Same-Day Duplicate",
    "Day Boundary Conflict": "Crosses Day Boundary",
    "Teacher Overlap": "Teacher Overlap",
    "Room Overlap": "Room Overlap",
    "Group Double-Book": "Group Double-Book",
    "Student Overlap": "Student Overlap",
    "Missing Enrollments": "Missing Enrollments",
    "Invalid Timeslot": "Invalid Timeslot",
}

def _parse_slot_label(slot_label):
    """Parse 'Monday - Period 2' into ('Monday', 2). Returns (None, None) on failure."""
    if not slot_label or " - Period " not in slot_label:
        return None, None
    try:
        parts = slot_label.split(" - Period ")
        return parts[0], int(parts[1])
    except Exception:
        return None, None


def _build_conflicts_from_snapshot(db: Session, version):
    """
    Build by_slot conflict data from immutable TimetableConflictModel records.
    This ensures historical timetables retain their original conflict state
    regardless of subsequent changes to teacher availability or other settings.
    """
    from backend.database.models.timetable_conflict import TimetableConflictModel
    from backend.database.models.timetable_conflict_type import TimetableConflictTypeModel

    version_id = version.version_id

    # Fetch all historical conflict records with their type names
    records = (
        db.query(
            TimetableConflictModel.conflict_type_id,
            TimetableConflictModel.entity_id,
            TimetableConflictModel.entity_name,
            TimetableConflictModel.slot_label,
            TimetableConflictModel.primary_enrollment_id,
            TimetableConflictModel.conflicting_enrollment_id,
            TimetableConflictTypeModel.name.label("db_type_name"),
        )
        .join(TimetableConflictTypeModel, TimetableConflictTypeModel.type_id == TimetableConflictModel.conflict_type_id)
        .filter(TimetableConflictModel.version_id == version_id)
        .all()
    )

    if not records:
        return None  # Signal caller to fall back to dynamic

    # Pre-load all entries for this version (these are immutable)
    all_entries = (
        db.query(
            TimetableEntryModel.entry_id,
            TimetableEntryModel.enrollment_id,
            TimetableEntryModel.slot_id,
            TimetableEntryModel.duration,
            TimetableEntryModel.room_id,
            EnrollmentModel.teacher_id,
            EnrollmentModel.group_id,
            TeacherModel.name.label("teacher_name"),
            SubjectModel.name.label("subject_name"),
            GroupModel.name.label("group_name"),
            ClassroomModel.name.label("room_name"),
        )
        .join(EnrollmentModel, EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id)
        .join(TeacherModel, TeacherModel.teacher_id == EnrollmentModel.teacher_id)
        .join(SubjectModel, SubjectModel.subject_id == EnrollmentModel.subject_id)
        .join(GroupModel, GroupModel.group_id == EnrollmentModel.group_id)
        .outerjoin(ClassroomModel, ClassroomModel.room_id == TimetableEntryModel.room_id)
        .filter(TimetableEntryModel.version_id == version_id)
        .all()
    )

    # Lookups: entry_id -> entry data (for precise detail messages)
    # enrollment_id -> entry data (as fallback)
    entry_lookup = {e.entry_id: e for e in all_entries}
    enroll_lookup = {e.enrollment_id: e for e in all_entries}

    # Slot lookups (must be built before slot_id_map)
    slots = db.query(SessionSlotModel).filter(
        SessionSlotModel.session_id == version.session_id
    ).all()
    slot_time_by_period = {(s.day, s.period_number): (s.start_time, s.end_time) for s in slots}

    # Slot-aware entry lookup: find the correct entry_id for a specific
    # enrollment at a specific (day, period). An enrollment can appear on
    # multiple days, so a flat enrollment_id->entry_id map would be wrong.
    slot_id_map = {s.slot_id: (s.day, s.period_number) for s in slots}
    # enrollment_id -> list of (entry_id, day, start_period, duration)
    enrollment_entries = {}
    for e in all_entries:
        e_day, e_period = slot_id_map.get(e.slot_id, (None, None))
        if e_day:
            enrollment_entries.setdefault(e.enrollment_id, []).append(
                (e.entry_id, e_day, e_period, e.duration)
            )

    def _find_entry_id(enrollment_id, target_day, target_period):
        """Find the entry_id for an enrollment at a specific day+period (handles multi-hour spans)."""
        for eid, eday, eperiod, edur in enrollment_entries.get(enrollment_id, []):
            if eday == target_day and eperiod <= target_period < eperiod + edur:
                return eid
        return None

    by_slot = {}
    type_counts = {}

    for rec in records:
        frontend_type = _DB_TYPE_TO_FRONTEND.get(rec.db_type_name, rec.db_type_name)
        day, period = _parse_slot_label(rec.slot_label)
        if day is None:
            continue

        key = f"{day}_{period}"
        
        # Build enrollment_ids and entry_ids using SLOT-AWARE lookup
        enrollment_ids = [rec.primary_enrollment_id] if rec.primary_enrollment_id else []
        entry_ids = []
        primary_eid = None
        if rec.primary_enrollment_id:
            primary_eid = _find_entry_id(rec.primary_enrollment_id, day, period)
            if primary_eid:
                entry_ids.append(primary_eid)
                
        conflicting_eid = None
        if rec.conflicting_enrollment_id:
            enrollment_ids.append(rec.conflicting_enrollment_id)
            conflicting_eid = _find_entry_id(rec.conflicting_enrollment_id, day, period)
            if conflicting_eid:
                entry_ids.append(conflicting_eid)

        # Get EXACT primary and conflicting entries for the detail messages
        primary = entry_lookup.get(primary_eid) if primary_eid else enroll_lookup.get(rec.primary_enrollment_id)
        conflicting = entry_lookup.get(conflicting_eid) if conflicting_eid else enroll_lookup.get(rec.conflicting_enrollment_id)

        # Build detail message
        times = slot_time_by_period.get((day, period), ("?", "?"))
        if frontend_type == "Availability" and primary:
            detail = f"{primary.teacher_name} is not available at this slot from {times[0]} to {times[1]} (teaching {primary.subject_name} for {primary.group_name})"
        elif frontend_type == "Teacher Overlap" and primary and conflicting:
            detail = f"{primary.teacher_name} is double-booked: {primary.subject_name} ({primary.group_name}) ↔ {conflicting.subject_name} ({conflicting.group_name})"
        elif frontend_type == "Room Overlap" and primary and conflicting:
            detail = f"{primary.room_name} has 2 classes: {primary.subject_name} ({primary.group_name}) ↔ {conflicting.subject_name} ({conflicting.group_name})"
        elif frontend_type == "Group Double-Book" and primary and conflicting:
            detail = f"{primary.group_name} has 2 classes: {primary.subject_name} ↔ {conflicting.subject_name}"
        elif frontend_type == "Student Overlap" and primary and conflicting:
            detail = f"Students in {primary.group_name} and {conflicting.group_name} are double-booked: {primary.subject_name} ↔ {conflicting.subject_name}"
        elif frontend_type == "Capacity" and primary:
            detail = f"Room {primary.room_name} too small for {primary.group_name}"
        elif frontend_type == "Type Mismatch" and primary:
            detail = f"{primary.subject_name} scheduled in {primary.room_name}"
        elif frontend_type == "Same-Day Duplicate" and primary:
            detail = f"{primary.subject_name} is already scheduled on {day} for {primary.group_name}"
        elif frontend_type == "Lunch Break Conflict" and primary:
            detail = f"{primary.subject_name} crosses lunch break"
        else:
            detail = rec.entity_name or f"Conflict at {rec.slot_label}"


        conflict_entry = {"type": frontend_type, "detail": detail}
        if enrollment_ids:
            conflict_entry["enrollment_ids"] = enrollment_ids
        if entry_ids:
            conflict_entry["entry_ids"] = entry_ids

        # Attach entity fields for the frontend to use in related highlighting
        if primary:
            conflict_entry["teacher"] = primary.teacher_name
            conflict_entry["group"] = primary.group_name
            conflict_entry["room"] = primary.room_name

        by_slot.setdefault(key, []).append(conflict_entry)
        type_counts[frontend_type] = type_counts.get(frontend_type, 0) + 1

    # Use stored GA summary for banner counts (matches generation feed)
    import json
    stored_summary = []
    if version.conflict_json:
        try:
            stored_summary = json.loads(version.conflict_json)
        except Exception:
            pass

    if stored_summary:
        summary = [{"type": item["type"], "count": item["count"]} for item in stored_summary]
        total = sum(item["count"] for item in stored_summary)
    else:
        summary = [{"type": k, "count": v} for k, v in type_counts.items()]
        total = sum(type_counts.values())

    return {"total": total, "summary": summary, "by_slot": by_slot}


# ------------------------------------------------
# Detailed Conflict Detection (slot-keyed for grid highlighting)
# ------------------------------------------------
def get_detailed_conflicts(db: Session, version_id: int):
    """
    Returns conflict data keyed by 'Day_Period' so the frontend can
    directly match cells for highlighting and hover tooltips.
    """
    version = db.query(TimetableVersionModel).filter(
        TimetableVersionModel.version_id == version_id
    ).first()

    if not version:
        return {"total": 0, "summary": [], "by_slot": {}}

    # ── STRICT SNAPSHOT MODE ──
    # Try to build conflicts from immutable TimetableConflictModel records
    # saved at generation time. This prevents stale data when users update
    # teacher availability or other settings after generation.
    snapshot_result = _build_conflicts_from_snapshot(db, version)
    if snapshot_result is not None:
        return snapshot_result

    # ── FALLBACK: Dynamic calculation for legacy versions ──
    from backend.database.models.session_slot import SessionSlotModel
    from backend.database.models.group_student import GroupStudentModel

    # Pre-load slot lookup: slot_id -> (day, period_number)
    slots = db.query(SessionSlotModel).filter(
        SessionSlotModel.session_id == version.session_id
    ).all()
    slot_map = {s.slot_id: (s.day, s.period_number) for s in slots}
    reverse_slot_map = {(s.day, s.period_number): s.slot_id for s in slots}
    slot_time_map = {s.slot_id: (s.start_time, s.end_time) for s in slots}

    # This dict maps "Day_Period" -> list of conflict descriptions
    by_slot = {}  # key: "Monday_1", value: [{"type": ..., "detail": ..., "room": ..., "teacher": ..., "group": ...}]

    def add_conflict(slot_id, conflict_type, detail, room=None, teacher=None, group=None, enrollment_ids=None, entry_ids=None):
        if slot_id not in slot_map:
            return
        day, period = slot_map[slot_id]
        key = f"{day}_{period}"
        if key not in by_slot:
            by_slot[key] = []
        entry = {"type": conflict_type, "detail": detail}
        if room: entry["room"] = room
        if teacher: entry["teacher"] = teacher
        if group: entry["group"] = group
        if enrollment_ids: entry["enrollment_ids"] = enrollment_ids
        if entry_ids: entry["entry_ids"] = entry_ids
        by_slot[key].append(entry)

    # Ensure all mapping data is present
    group_students = db.query(GroupStudentModel.group_id, GroupStudentModel.student_id).all()
    group_student_map = {}
    for gs in group_students:
        group_student_map.setdefault(gs.group_id, set()).add(gs.student_id)
        
    group_counts = {gid: len(stus) for gid, stus in group_student_map.items()}

    # Get all entries with fully expanded details
    all_entries = (
        db.query(
            TimetableEntryModel.entry_id,
            TimetableEntryModel.enrollment_id,
            TimetableEntryModel.slot_id,
            TimetableEntryModel.duration,
            EnrollmentModel.teacher_id,
            EnrollmentModel.group_id,
            TimetableEntryModel.room_id,
            TeacherModel.name.label("teacher_name"),
            SubjectModel.name.label("subject_name"),
            SubjectModel.subject_type.label("subject_type"),
            GroupModel.name.label("group_name"),
            ClassroomModel.name.label("room_name"),
            ClassroomModel.room_type.label("room_type"),
            ClassroomModel.capacity.label("room_capacity"),
        )
        .join(EnrollmentModel, EnrollmentModel.enrollment_id == TimetableEntryModel.enrollment_id)
        .join(TeacherModel, TeacherModel.teacher_id == EnrollmentModel.teacher_id)
        .join(SubjectModel, SubjectModel.subject_id == EnrollmentModel.subject_id)
        .join(GroupModel, GroupModel.group_id == EnrollmentModel.group_id)
        .outerjoin(ClassroomModel, ClassroomModel.room_id == TimetableEntryModel.room_id)
        .filter(TimetableEntryModel.version_id == version_id)
        .all()
    )

    avail_rows = db.query(SessionTeacherAvailabilityModel.teacher_id, SessionTeacherAvailabilityModel.slot_id).all()
    avail_set = set((r.teacher_id, r.slot_id) for r in avail_rows)
    teachers_with_avail = set(r.teacher_id for r in avail_rows)

    teacher_schedule = {} # slot_id -> list of entries
    room_schedule = {}    # slot_id -> list of entries
    group_schedule = {}   # slot_id -> list of entries
    enrollment_day_tracker = set()

    
    for e in all_entries:
        day, start_p = slot_map.get(e.slot_id, (None, None))
        if not day: continue

        # --- 1. Type Mismatch ---
        if e.room_type and e.subject_type:
            if e.room_type.lower() != e.subject_type.lower():
                add_conflict(
                    e.slot_id,
                    "Type Mismatch",
                    f"{e.subject_name} ({e.subject_type}) scheduled in {e.room_name} ({e.room_type})",
                    room=e.room_name,
                    group=e.group_name,
                    teacher=e.teacher_name,
                    enrollment_ids=[e.enrollment_id],
                    entry_ids=[e.entry_id]
                )
                
        # --- 2. Capacity Mismatch ---
        st_count = group_counts.get(e.group_id, 0)
        if st_count > 0 and e.room_capacity is not None and e.room_capacity < st_count:
            add_conflict(
                e.slot_id,
                "Capacity",
                f"Room {e.room_name} (capacity {e.room_capacity}) too small for {e.group_name} ({st_count} students)",
                room=e.room_name,
                group=e.group_name,
                teacher=e.teacher_name,
                enrollment_ids=[e.enrollment_id],
                entry_ids=[e.entry_id]
            )
            
        # --- 3. Lunch Break Crossover ---
        end_p = start_p + e.duration - 1
        if start_p <= 4 and end_p >= 5:
            add_conflict(
                e.slot_id,
                "Lunch Break Conflict",
                f"{e.subject_name} crosses lunch break",
                room=e.room_name,
                group=e.group_name,
                teacher=e.teacher_name,
                enrollment_ids=[e.enrollment_id],
                entry_ids=[e.entry_id]
            )

        # --- 4. Same Day Duplicate ---
        # A specific class cannot be scheduled twice on the same day
        key = (e.enrollment_id, day)
        if key in enrollment_day_tracker:
            add_conflict(
                e.slot_id,
                "Same-Day Duplicate",
                f"{e.subject_name} is already scheduled on {day} for {e.group_name}",
                room=e.room_name,
                group=e.group_name,
                teacher=e.teacher_name,
                enrollment_ids=[e.enrollment_id],
                entry_ids=[e.entry_id]
            )
        else:
            enrollment_day_tracker.add(key)

        # Map out duration
        for d in range(e.duration):
            current_p = start_p + d
            check_slot_id = reverse_slot_map.get((day, current_p))
            if not check_slot_id: continue

            # --- 5. Availability ---
            if e.teacher_id in teachers_with_avail:
                if (e.teacher_id, check_slot_id) not in avail_set:
                    start_time, end_time = slot_time_map.get(check_slot_id, ("?", "?"))
                    add_conflict(
                        check_slot_id,
                        "Availability",
                        f"{e.teacher_name} is not available at this slot from {start_time} to {end_time} (teaching {e.subject_name} for {e.group_name})",
                        teacher=e.teacher_name,
                        group=e.group_name,
                        room=e.room_name,
                        enrollment_ids=[e.enrollment_id],
                        entry_ids=[e.entry_id]
                    )
            
            # Record for overlap checks
            teacher_schedule.setdefault(check_slot_id, []).append(e)
            if e.room_id is not None:
                room_schedule.setdefault(check_slot_id, []).append(e)
            group_schedule.setdefault(check_slot_id, []).append(e)

    # -----------------------------------------------------------------------
    # Helper: build a human-readable class descriptor that makes multi-period
    # classes unambiguous.  When the overlap is detected at a *continuation*
    # slot (not the class's own start slot) we append a note so the user
    # understands why they see a conflict at a slot where the class appears
    # as a blank/continuation cell rather than a "start" cell.
    #
    #   e.g.  "OS (CS-A) [15:00-17:00, started P7]"   ← 2-hr class starting P7
    #         "ML (CS-B) [16:00-17:00]"                ← 1-hr class starting P8
    # -----------------------------------------------------------------------
    def _class_descriptor(e, conflict_slot_id):
        e_day, e_start_p = slot_map.get(e.slot_id, (None, None))
        if e_start_p is None:
            return f"{e.subject_name}"

        e_end_p = e_start_p + e.duration - 1
        start_sid = e.slot_id
        end_sid = reverse_slot_map.get((e_day, e_end_p))
        s_time = slot_time_map.get(start_sid, ("?",))[0]
        e_time = slot_time_map.get(end_sid, ("?", "?"))[1] if end_sid else "?"
        time_range = f"{s_time}–{e_time}"

        # If the conflict was detected at a slot OTHER than this class's start
        # slot, clarify that the class merely extends into this slot.
        if e.duration > 1 and e.slot_id != conflict_slot_id:
            conflict_day, conflict_p = slot_map.get(conflict_slot_id, (None, None))
            return f"{e.subject_name} [{time_range}, {e.duration}h class starting P{e_start_p}]"
        return f"{e.subject_name} [{time_range}]"

    # Process overlaps — build clearer messages showing each class's actual time range
    for slot_id, entries in teacher_schedule.items():
        t_groups = {}
        for e in entries: t_groups.setdefault(e.teacher_id, []).append(e)
        for t_id, e_list in t_groups.items():
            if len(e_list) > 1:
                t_name = e_list[0].teacher_name
                parts = [
                    f"{_class_descriptor(e, slot_id)} ({e.group_name})"
                    for e in e_list
                ]
                eids = [e.enrollment_id for e in e_list]
                entry_ids = [e.entry_id for e in e_list]
                add_conflict(slot_id, "Teacher Overlap", f"{t_name} is double-booked: {' ↔ '.join(parts)}", teacher=t_name, enrollment_ids=eids, entry_ids=entry_ids)

    for slot_id, entries in room_schedule.items():
        r_groups = {}
        for e in entries: r_groups.setdefault(e.room_id, []).append(e)
        for r_id, e_list in r_groups.items():
            if len(e_list) > 1:
                r_name = e_list[0].room_name
                parts = [
                    f"{_class_descriptor(e, slot_id)} ({e.group_name})"
                    for e in e_list
                ]
                eids = [e.enrollment_id for e in e_list]
                entry_ids = [e.entry_id for e in e_list]
                add_conflict(slot_id, "Room Overlap", f"{r_name} has {len(e_list)} classes: {' ↔ '.join(parts)}", room=r_name, enrollment_ids=eids, entry_ids=entry_ids)

    for slot_id, entries in group_schedule.items():
        g_groups = {}
        for e in entries: g_groups.setdefault(e.group_id, []).append(e)
        for g_id, e_list in g_groups.items():
            if len(e_list) > 1:
                g_name = e_list[0].group_name
                parts = [
                    f"{_class_descriptor(e, slot_id)} by {e.teacher_name}"
                    for e in e_list
                ]
                eids = [e.enrollment_id for e in e_list]
                entry_ids = [e.entry_id for e in e_list]
                add_conflict(slot_id, "Group Double-Book", f"{g_name} has {len(e_list)} classes: {' ↔ '.join(parts)}", group=g_name, enrollment_ids=eids, entry_ids=entry_ids)

    # --- Student Overlap ---
    for slot_id, entries in group_schedule.items():
        for i in range(len(entries)):
            for j in range(i + 1, len(entries)):
                e1 = entries[i]
                e2 = entries[j]
                if e1.group_id == e2.group_id: continue

                stu1 = group_student_map.get(e1.group_id, set())
                stu2 = group_student_map.get(e2.group_id, set())

                intersect = stu1.intersection(stu2)
                if len(intersect) > 0:
                    msg = f"{len(intersect)} students in both {e1.group_name} and {e2.group_name} are double-booked: {e1.subject_name} ↔ {e2.subject_name}"

                    eids = [e1.enrollment_id, e2.enrollment_id]
                    entry_ids = [e1.entry_id, e2.entry_id]
                    add_conflict(slot_id, "Student Overlap", msg, group=e1.group_name, teacher=e1.teacher_name, room=e1.room_name, enrollment_ids=eids, entry_ids=entry_ids)
                    add_conflict(slot_id, "Student Overlap", msg, group=e2.group_name, teacher=e2.teacher_name, room=e2.room_name, enrollment_ids=eids, entry_ids=entry_ids)

    # Also include stored GA-level conflict logs for anything we can't detect from DB
    stored_summary = []
    if version.conflict_json:
        import json
        try:
            stored_summary = json.loads(version.conflict_json)
        except Exception:
            stored_summary = []

    # Build summary from by_slot data
    type_counts = {}
    for key, conflict_list in by_slot.items():
        for c in conflict_list:
            type_counts[c["type"]] = type_counts.get(c["type"], 0) + 1

    # Keep totals consistent across app screens:
    # - Generation feed / version cards use stored GA conflict_log
    # - Explorer details (by_slot) can still be DB-detected for hover/debug
    if stored_summary:
        summary = [{"type": item["type"], "count": item["count"]} for item in stored_summary]
        total = sum(item["count"] for item in stored_summary)
    elif type_counts:
        summary = [{"type": k, "count": v} for k, v in type_counts.items()]
        total = sum(type_counts.values())
    elif version.best_violation and version.best_violation > 0:
        summary = [{"type": "Scheduling Violations", "count": version.best_violation}]
        total = version.best_violation
    else:
        summary = []
        total = 0

    return {
        "total": total,
        "summary": summary,
        "by_slot": by_slot,
    }
