from typing import Dict, List, Tuple

from backend.scheduler_engine.entities import *

# ------------------ TYPE DEFINITIONS ------------------

Gene = Tuple[int, int, int, int]  # (enrollment_id, room_id, start_slot, duration)
Chromosome = List[Gene]


# ------------------ HARD CONSTRAINT ENGINE ------------------

def constraint_violation(
    chromosome: Chromosome,
    enrollments,
    teachers,
    classrooms,
    groups,
    subjects,
    group_conflicts,
    total_slots,
    slot_day_map,
    slot_period_map,
    return_breakdown=False,
    capture_details=False
):
    """
    Evaluate hard-constraint violations for a chromosome.

    When *capture_details* is True the function also records per-instance
    conflict detail dicts (entity_id, entity_name, slot_label, etc.)
    suitable for persisting into the ``timetable_conflict`` table.
    This mode is intentionally heavier and should only be called on the
    **final best individual**, never inside the main GA loop.
    """

    # -------------------------------
    # SCHEDULE TRACKERS
    # When capture_details is True we store dict(slot -> enrollment_idx)
    # so we can identify the *other* enrollment involved in a clash.
    # Otherwise we keep the lightweight set() for speed.
    # -------------------------------
    if capture_details:
        teacher_schedule: Dict[int, dict] = {}   # teacher_id -> {slot: enrollment_idx}
        room_schedule: Dict[int, dict] = {}      # room_id   -> {slot: enrollment_idx}
        group_schedule: Dict[int, dict] = {}     # group_id  -> {slot: enrollment_idx}
    else:
        teacher_schedule: Dict[int, set] = {}
        room_schedule: Dict[int, set] = {}
        group_schedule: Dict[int, set] = {}

    # 🔥 STRICT: enrollment per day uniqueness
    enrollment_day_tracker = set()

    breakdown = {
        "invalid_timeslot": 0,
        "teacher_conflict": 0,
        "room_conflict": 0,
        "group_conflict": 0,
        "student_overlap": 0,
        "availability": 0,
        "capacity": 0,
        "type_mismatch": 0,
        "same_day_duplicate": 0,
        "missing_enrollments": 0,
        "day_boundary_conflict": 0,
        "lunch_break_conflict": 0  # 🔥
    }

    # Detail list — only populated when capture_details=True
    details: List[dict] = []

    def _slot_label(slot_idx):
        """Build a human-readable label like 'Monday - Period 3'."""
        return f"{slot_day_map.get(slot_idx, '?')} - Period {slot_period_map.get(slot_idx, '?')}"

    # -------------------------------
    # MAIN LOOP
    # -------------------------------
    for gene_idx, gene in enumerate(chromosome):
        enrollment_id, room_id, start_slot, duration = gene

        # ---------- BASIC FETCH ----------
        enrollment = enrollments[enrollment_id]
        teacher = teachers[enrollment.teacher_id]
        group = groups[enrollment.group_id]
        subject = subjects[enrollment.subject_id]
        room = classrooms[room_id]

        # -------------------------------
        # 1️⃣ TIMESLOT VALIDITY
        # -------------------------------
        if start_slot < 0 or start_slot + duration > total_slots:
            breakdown["invalid_timeslot"] += 100
            if capture_details:
                details.append({
                    "key": "invalid_timeslot",
                    "entity_id": enrollment.enrollment_id,
                    "entity_name": f"Enrollment #{enrollment.enrollment_id}",
                    "slot_label": f"start={start_slot}, dur={duration}",
                    "primary_enrollment_id": enrollment.enrollment_id,
                    "conflicting_enrollment_id": None,
                })
            continue

        if slot_day_map[start_slot] != slot_day_map[start_slot + duration - 1]:
            breakdown["day_boundary_conflict"] += 500
            if capture_details:
                details.append({
                    "key": "day_boundary_conflict",
                    "entity_id": enrollment.enrollment_id,
                    "entity_name": f"Enrollment #{enrollment.enrollment_id}",
                    "slot_label": f"{_slot_label(start_slot)} → {_slot_label(start_slot + duration - 1)}",
                    "primary_enrollment_id": enrollment.enrollment_id,
                    "conflicting_enrollment_id": None,
                })

        # 🔥 Lunch Break Crossing (P4-P5 gap)
        start_p = slot_period_map[start_slot]
        end_p = slot_period_map[start_slot + duration - 1]
        if start_p <= 4 and end_p >= 5:
            breakdown["lunch_break_conflict"] += 100000
            if capture_details:
                details.append({
                    "key": "lunch_break_conflict",
                    "entity_id": enrollment.enrollment_id,
                    "entity_name": f"Enrollment #{enrollment.enrollment_id}",
                    "slot_label": f"{_slot_label(start_slot)} → {_slot_label(start_slot + duration - 1)}",
                    "primary_enrollment_id": enrollment.enrollment_id,
                    "conflicting_enrollment_id": None,
                })

        occupied_slots = range(start_slot, start_slot + duration)

        # -------------------------------
        # 2️⃣ 🔥 SAME ENROLLMENT SAME DAY (STRICT)
        # -------------------------------
        day = slot_day_map[start_slot]
        key = (enrollment.enrollment_id, day)

        if key in enrollment_day_tracker:
            breakdown["same_day_duplicate"] += 1000
            if capture_details:
                details.append({
                    "key": "same_day_duplicate",
                    "entity_id": enrollment.enrollment_id,
                    "entity_name": f"Enrollment #{enrollment.enrollment_id}",
                    "slot_label": _slot_label(start_slot),
                    "primary_enrollment_id": enrollment.enrollment_id,
                    "conflicting_enrollment_id": None,
                })
        else:
            enrollment_day_tracker.add(key)

        # -------------------------------
        # 3️⃣ AVAILABILITY
        # -------------------------------
        for t in occupied_slots:
            if t not in teacher.available_slots:
                breakdown["availability"] += 1
                if capture_details:
                    details.append({
                        "key": "availability",
                        "entity_id": enrollment.teacher_id,
                        "entity_name": f"Teacher #{enrollment.teacher_id}",
                        "slot_label": _slot_label(t),
                        "primary_enrollment_id": enrollment.enrollment_id,
                        "conflicting_enrollment_id": None,
                    })

        # -------------------------------
        # 4️⃣ CAPACITY
        # -------------------------------
        if room.capacity < len(group.students):
            breakdown["capacity"] += 1
            if capture_details:
                details.append({
                    "key": "capacity",
                    "entity_id": room.room_id,
                    "entity_name": f"Room #{room.room_id}",
                    "slot_label": _slot_label(start_slot),
                    "primary_enrollment_id": enrollment.enrollment_id,
                    "conflicting_enrollment_id": None,
                })

        # -------------------------------
        # 5️⃣ TYPE MISMATCH
        # -------------------------------
        if subject.subject_type != room.room_type:
            breakdown["type_mismatch"] += 1
            if capture_details:
                details.append({
                    "key": "type_mismatch",
                    "entity_id": room.room_id,
                    "entity_name": f"Room #{room.room_id} ({room.room_type})",
                    "slot_label": _slot_label(start_slot),
                    "primary_enrollment_id": enrollment.enrollment_id,
                    "conflicting_enrollment_id": None,
                })

        # -------------------------------
        # 6️⃣ TEACHER CONFLICT
        # -------------------------------
        if capture_details:
            ts = teacher_schedule.setdefault(teacher.teacher_id, {})
            for t in occupied_slots:
                if t in ts:
                    breakdown["teacher_conflict"] += 10
                    details.append({
                        "key": "teacher_conflict",
                        "entity_id": teacher.teacher_id,
                        "entity_name": f"Teacher #{teacher.teacher_id}",
                        "slot_label": _slot_label(t),
                        "primary_enrollment_id": enrollment.enrollment_id,
                        "conflicting_enrollment_id": enrollments[ts[t]].enrollment_id,
                    })
                ts[t] = enrollment_id
        else:
            ts = teacher_schedule.setdefault(teacher.teacher_id, set())
            for t in occupied_slots:
                if t in ts:
                    breakdown["teacher_conflict"] += 10
                ts.add(t)

        # -------------------------------
        # 7️⃣ ROOM CONFLICT
        # -------------------------------
        if capture_details:
            rs = room_schedule.setdefault(room.room_id, {})
            for t in occupied_slots:
                if t in rs:
                    breakdown["room_conflict"] += 10
                    details.append({
                        "key": "room_conflict",
                        "entity_id": room.room_id,
                        "entity_name": f"Room #{room.room_id}",
                        "slot_label": _slot_label(t),
                        "primary_enrollment_id": enrollment.enrollment_id,
                        "conflicting_enrollment_id": enrollments[rs[t]].enrollment_id,
                    })
                rs[t] = enrollment_id
        else:
            rs = room_schedule.setdefault(room.room_id, set())
            for t in occupied_slots:
                if t in rs:
                    breakdown["room_conflict"] += 10
                rs.add(t)

        # -------------------------------
        # 8️⃣ GROUP CONFLICT
        # -------------------------------
        if capture_details:
            gs = group_schedule.setdefault(group.group_id, {})
            for t in occupied_slots:
                if t in gs:
                    breakdown["group_conflict"] += 10
                    details.append({
                        "key": "group_conflict",
                        "entity_id": group.group_id,
                        "entity_name": f"Group #{group.group_id}",
                        "slot_label": _slot_label(t),
                        "primary_enrollment_id": enrollment.enrollment_id,
                        "conflicting_enrollment_id": enrollments[gs[t]].enrollment_id,
                    })
                gs[t] = enrollment_id
        else:
            gs = group_schedule.setdefault(group.group_id, set())
            for t in occupied_slots:
                if t in gs:
                    breakdown["group_conflict"] += 10
                gs.add(t)

        # -------------------------------
        # 9️⃣ STUDENT OVERLAP
        # -------------------------------
        for conflicting_group_id in group_conflicts.get(group.group_id, set()):
            if conflicting_group_id in group_schedule:
                conflicting_slots = group_schedule[conflicting_group_id]
                for t in occupied_slots:
                    if capture_details:
                        if t in conflicting_slots:
                            breakdown["student_overlap"] += 5
                            details.append({
                                "key": "student_overlap",
                                "entity_id": group.group_id,
                                "entity_name": f"Group #{group.group_id} ↔ Group #{conflicting_group_id}",
                                "slot_label": _slot_label(t),
                                "primary_enrollment_id": enrollment.enrollment_id,
                                "conflicting_enrollment_id": enrollments[conflicting_slots[t]].enrollment_id,
                            })
                    else:
                        if t in conflicting_slots:
                            breakdown["student_overlap"] += 5

    # -------------------------------
    # 🔟 MISSING ENROLLMENTS
    # -------------------------------
    present_ids = set(g[0] for g in chromosome)
    missing = len(enrollments) - len(present_ids)

    # 🔥 STRONG penalty for missing
    breakdown["missing_enrollments"] = missing * 1000

    if capture_details and missing > 0:
        all_ids = set(enrollments.keys())
        for m_id in all_ids - present_ids:
            details.append({
                "key": "missing_enrollments",
                "entity_id": enrollments[m_id].enrollment_id,
                "entity_name": f"Enrollment #{enrollments[m_id].enrollment_id}",
                "slot_label": None,
                "primary_enrollment_id": enrollments[m_id].enrollment_id,
                "conflicting_enrollment_id": None,
            })

    total_violation = sum(breakdown.values())

    # -------------------------------
    # RETURN
    # -------------------------------
    if capture_details:
        return total_violation, breakdown, details

    if return_breakdown:
        return total_violation, breakdown

    return total_violation