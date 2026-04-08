from typing import Dict, Set
from sqlalchemy.orm import Session
import logging
import sys

# Setup logger for Uvicorn visibility
logger = logging.getLogger("uvicorn.error")

# Import DB models
from backend.database.models.branch import BranchModel
from backend.database.models.student import StudentModel
from backend.database.models.group import GroupModel
from backend.database.models.group_student import GroupStudentModel
from backend.database.models.teacher import TeacherModel
from backend.database.models.teacher_availability import SessionTeacherAvailabilityModel
from backend.database.models.classroom import ClassroomModel
from backend.database.models.subject import SubjectModel
from backend.database.models.enrollment import EnrollmentModel
from backend.database.models.slot import SlotModel
from backend.database.models.session_slot import SessionSlotModel
from backend.database.models.session_entities import (
    SessionTeacherModel,
    SessionSubjectModel,
    SessionGroupModel,
    SessionClassroomModel,
)
from backend.api.services.teacher_availability_service import get_teacher_availability

# Import ENGINE dataclasses
from backend.scheduler_engine.entities import (
    Branch,
    Student,
    Group,
    Teacher,
    Classroom,
    Subject,
    Enrollment
)


def load_engine_data(db: Session, session_id: int):
    logger.info("  -> Starting data load: slots")
    # -------------------------
    # 1️⃣ Load Slots & Mapping (session-scoped via dedicated model)
    # -------------------------
    model = SlotModel if session_id == -1 else SessionSlotModel
    db_slots = db.query(model).filter(
        model.session_id == session_id,
        model.status == 1 # Only load active slots into the engine
    ).order_by(model.slot_id).all()

    slot_index_map = {}
    reverse_slot_map = {}
    slot_day_map = {}
    slot_period_map = {}

    for index, slot in enumerate(db_slots):
        slot_index_map[slot.slot_id] = index
        reverse_slot_map[index] = slot.slot_id

        slot_day_map[index] = slot.day
        slot_period_map[index] = slot.period_number

    total_slots = len(db_slots)

    # -------------------------
    # 2️⃣ Load Branches & Students
    # -------------------------
    logger.info("  -> Loading branches & students")

    branches: Dict[int, Branch] = {}
    students: Dict[str, Student] = {}

    # Branches and Students are global (not session-scoped)
    db_branches = db.query(BranchModel).all()
    db_students = db.query(StudentModel).all()

    for s in db_students:
        students[s.student_id] = Student(
            student_id=s.student_id,
            branch_id=s.branch_id
        )

    for b in db_branches:

        branch_students = {
            s.student_id
            for s in db_students
            if s.branch_id == b.branch_id
        }

        branches[b.branch_id] = Branch(
            branch_id=b.branch_id,
            name=b.name,
            students=branch_students
        )

    # -------------------------
    # 3️⃣ Load Groups
    # -------------------------
    logger.info("  -> Loading groups")

    groups: Dict[int, Group] = {}

    # Groups linked to session via junction table
    db_groups = db.query(GroupModel).join(
        SessionGroupModel, GroupModel.group_id == SessionGroupModel.group_id
    ).filter(SessionGroupModel.session_id == session_id).all()
    db_group_students = db.query(GroupStudentModel).all()

    for g in db_groups:

        group_student_ids = {
            gs.student_id
            for gs in db_group_students
            if gs.group_id == g.group_id
        }

        groups[g.group_id] = Group(
            group_id=g.group_id,
            name=g.name,
            students=group_student_ids
        )

    # -------------------------
    # 4️⃣ Load Teachers
    # -------------------------
    logger.info("  -> Loading teachers")

    teachers: Dict[int, Teacher] = {}

    # Teachers linked to session via junction table
    db_teachers = db.query(TeacherModel).join(
        SessionTeacherModel, TeacherModel.teacher_id == SessionTeacherModel.teacher_id
    ).filter(SessionTeacherModel.session_id == session_id).all()
    for t in db_teachers:

        available_slots = set()
        slot_preferences = {}

        # Use the Master-Override service to fetch correctly for this session
        avail_response = get_teacher_availability(db, t.teacher_id, session_id)
        entries = avail_response.get("entries", [])
        
        # Helper to map Global Day-Period to a session index if needed
        # (Though most common use case is Session Mode which has slot_id)
        for ta in entries:
            # Handle potential dictionary or object return types gracefully
            is_dict = isinstance(ta, dict)
            slot_index = None
            
            # CASE 1: Session-Specific (Modern junction model)
            s_id = ta.get("slot_id") if is_dict else getattr(ta, "slot_id", None)
            
            if s_id is not None:
                if s_id in slot_index_map:
                    slot_index = slot_index_map[s_id]
            
            # CASE 2: Global (Legacy/Fallback) - use day/period lookup
            else:
                d = ta.get("day") if is_dict else getattr(ta, "day", None)
                p = ta.get("period") if is_dict else getattr(ta, "period", None)
                
                if d is not None and p is not None:
                    # Need to find matching slot in this session
                    for idx, (s_day, s_period) in slot_day_map.items():
                        if s_day == d and slot_period_map[idx] == p:
                            slot_index = idx
                            break

            if slot_index is not None:
                available_slots.add(slot_index)
                rank = ta.get("preference_rank", 5) if is_dict else getattr(ta, "preference_rank", 5)
                slot_preferences[slot_index] = rank

        # 🔥 FALLBACK: If teacher has NO availability configured at all (Global or Session),
        # treat ALL session slots as available (rank 5 = neutral).
        if not available_slots and total_slots > 0:
            print(f"  [WARN] Teacher {t.teacher_id} ({t.name}) has NO availability configured. "
                  f"Auto-assigning all {total_slots} session slots.", file=sys.stderr, flush=True)
            for idx in range(total_slots):
                available_slots.add(idx)
                slot_preferences[idx] = 5

        teachers[t.teacher_id] = Teacher(
            teacher_id=t.teacher_id,
            available_slots=available_slots,
            slot_preferences=slot_preferences
        )

    # -------------------------
    # 5️⃣ Load Classrooms
    # -------------------------
    logger.info("  -> Loading classrooms")

    classrooms: Dict[int, Classroom] = {}

    # Classrooms linked to session via junction table
    db_classrooms = db.query(ClassroomModel).join(
        SessionClassroomModel, ClassroomModel.room_id == SessionClassroomModel.room_id
    ).filter(SessionClassroomModel.session_id == session_id).all()

    for r in db_classrooms:
        classrooms[r.room_id] = Classroom(
            room_id=r.room_id,
            capacity=r.capacity,
            room_type=r.room_type
        )

    # -------------------------
    # 6️⃣ Load Subjects
    # -------------------------
    logger.info("  -> Loading subjects")

    subjects: Dict[int, Subject] = {}

    # Subjects linked to session via junction table
    db_subjects = db.query(SubjectModel).join(
        SessionSubjectModel, SubjectModel.subject_id == SessionSubjectModel.subject_id
    ).filter(SessionSubjectModel.session_id == session_id).all()

    for s in db_subjects:
        subjects[s.subject_id] = Subject(
            subject_id=s.subject_id,
            name=s.name,
            subject_type=s.subject_type,
            hours_per_week=s.hours_per_week
        )

    # -------------------------
    # 7️⃣ Load Enrollments
    # -------------------------
    logger.info("  -> Loading enrollments")
    print("[LOADER] Step 7: querying enrollments from DB...", file=sys.stderr, flush=True)

    base_enrollments: Dict[int, Enrollment] = {}

    db_enrollments = db.query(EnrollmentModel).filter(EnrollmentModel.session_id == session_id).all()

    for e in db_enrollments:
        partition_list = []
        if e.partition and e.partition.strip():
            try:
                partition_list = [int(p.strip()) for p in e.partition.split(",") if p.strip()]
            except ValueError:
                partition_list = []

        base_enrollments[e.enrollment_id] = Enrollment(
            enrollment_id=e.enrollment_id,
            group_id=e.group_id,
            subject_id=e.subject_id,
            teacher_id=e.teacher_id,
            partition=partition_list
        )

    # -------------------------
    # 7.5️⃣ EXPAND ENROLLMENTS
    # -------------------------
    logger.info("  -> Expanding enrollments")

    enrollments: Dict[int, Enrollment] = {}
    expanded_id = 0

    for e in base_enrollments.values():

        subject = subjects[e.subject_id]
        
        # Fallback if partition is unexpectedly empty
        blocks = e.partition if e.partition else [1] * (subject.hours_per_week or 1)

        for duration in blocks:
            enrollments[expanded_id] = Enrollment(
                enrollment_id=e.enrollment_id,  # ✅ KEEP ORIGINAL ID
                group_id=e.group_id,
                subject_id=e.subject_id,
                teacher_id=e.teacher_id,
                partition=e.partition,
                duration=duration
            )
            expanded_id += 1

    # -------------------------
    # 🚨 FEASIBILITY CHECK
    # -------------------------

    total_required = {}
    for e in enrollments.values():
        s_type = subjects[e.subject_id].subject_type
        total_required[s_type] = total_required.get(s_type, 0) + e.duration

    capacity = {}
    for r in classrooms.values():
        r_type = r.room_type
        capacity[r_type] = capacity.get(r_type, 0) + total_slots

    # -------------------------
    # 🚨 FEASIBILITY CHECK (Legacy/Cleaned)
    # -------------------------
    is_feasible_legacy = True
    # (Kept for compatibility with return signature, but logic moved below)


    # -------------------------
    # 8️⃣ Build Group Conflicts
    # -------------------------
    logger.info("  -> Building group conflicts")

    group_conflicts: Dict[int, Set[int]] = {
        g_id: set() for g_id in groups
    }

    group_list = list(groups.values())

    for i in range(len(group_list)):
        for j in range(i + 1, len(group_list)):

            if group_list[i].students & group_list[j].students:

                group_conflicts[group_list[i].group_id].add(
                    group_list[j].group_id
                )

                group_conflicts[group_list[j].group_id].add(
                    group_list[i].group_id
                )

    # -------------------------
    # Feasibility Pre-Check (Detailed)
    # -------------------------
    logger.info("  -> Feasibility Pre-Check")
    total_required = {"theory": 0, "lab": 0}
    capacity = {"theory": 0, "lab": 0}

    for e in base_enrollments.values():
        sub = subjects[e.subject_id]
        rtype = sub.subject_type.lower()
        total_required[rtype] = total_required.get(rtype, 0) + sub.hours_per_week

    for r in classrooms.values():
        rtype = r.room_type.lower()
        capacity[rtype] = capacity.get(rtype, 0) + total_slots

    is_feasible = True
    for ctype in ["theory", "lab"]:
        if total_required[ctype] > capacity[ctype]:
            is_feasible = False

    # -------------------------
    # Return Engine Data
    # -------------------------

    return (
        branches,
        students,
        groups,
        teachers,
        classrooms,
        subjects,
        enrollments,
        group_conflicts,
        total_slots,
        reverse_slot_map,
        slot_day_map,
        slot_period_map,
        total_required,
        capacity,
        is_feasible
    )