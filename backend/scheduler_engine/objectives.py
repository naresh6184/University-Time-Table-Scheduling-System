from typing import Dict, List, Tuple
from backend.scheduler_engine.entities import *

Gene = Tuple[int, int, int, int]  # (enrollment_id, room_id, start_slot, duration)


# ============================================================
# 🔥 SUBJECT DISTRIBUTION (FIXED — NOW INCLUDES SAME-DAY PENALTY)
# ============================================================

def subject_distribution_score(chromosome, enrollments, slot_day_map):

    subject_day_count = {}
    same_day_penalty = 0.0

    for e_id, _, start, _ in chromosome:
        e = enrollments[e_id]
        key = (e.group_id, e.subject_id)

        day = slot_day_map[start]

        subject_day_count.setdefault(key, {}).setdefault(day, 0)
        subject_day_count[key][day] += 1

    variance_penalty = 0.0

    for days in subject_day_count.values():
        counts = list(days.values())

        # 🔥 STRONG same-day penalty
        for c in counts:
            if c > 1:
                same_day_penalty += (c - 1) * 10   # 🔥 increase weight

        if len(counts) <= 1:
            continue

        avg = sum(counts) / len(counts)
        variance = sum((c - avg) ** 2 for c in counts) / len(counts)

        variance_penalty += variance

    # ❗ ONLY light normalization
    variance_penalty /= max(1, len(subject_day_count))

    # ❗ DO NOT normalize same_day_penalty

    return variance_penalty + same_day_penalty

# ============================================================
# MAIN OBJECTIVES
# ============================================================

def compute_objectives(
    chromosome: List[Gene],
    enrollments: Dict[int, Enrollment],
    teachers: Dict[int, Teacher],
    classrooms: Dict[int, Classroom],
    groups: Dict[int, Group],
    slot_day_map,
    slot_period_map
):
    """
    Returns:
    (student_gap, teacher_gap, room_waste, teacher_dissatisfaction, subject_distribution)
    """

    if not chromosome:
        return (0.0, 0.0, 0.0, 0.0, 0.0)

    total_sessions = len(chromosome)
    max_periods_per_day = 8  # adjust if needed

    # =========================================================
    # 1️⃣ STUDENT GAP (NORMALIZED)
    # =========================================================

    group_day_slots = {}

    for enrollment_id, _, start_slot, duration in chromosome:
        group_id = enrollments[enrollment_id].group_id

        for t in range(start_slot, start_slot + duration):
            if t not in slot_day_map:
                continue
            day = slot_day_map[t]
            slot = slot_period_map[t]

            group_day_slots.setdefault(group_id, {}).setdefault(day, []).append(slot)

    student_gap = 0.0

    for days in group_day_slots.values():
        for slots in days.values():
            if len(slots) <= 1:
                continue

            slots.sort()
            for i in range(len(slots) - 1):
                gap = slots[i + 1] - slots[i] - 1
                if gap > 0:
                    student_gap += gap

    if group_day_slots:
        student_gap /= (len(group_day_slots) * max_periods_per_day)
    else:
        student_gap = 0.0

    # =========================================================
    # 2️⃣ TEACHER GAP (NORMALIZED)
    # =========================================================

    teacher_day_slots = {}

    for enrollment_id, _, start_slot, duration in chromosome:
        teacher_id = enrollments[enrollment_id].teacher_id

        for t in range(start_slot, start_slot + duration):
            if t not in slot_day_map:
                continue
            day = slot_day_map[t]
            slot = slot_period_map[t]

            teacher_day_slots.setdefault(teacher_id, {}).setdefault(day, []).append(slot)

    teacher_gap = 0.0

    for days in teacher_day_slots.values():
        for slots in days.values():
            if len(slots) <= 1:
                continue

            slots.sort()
            for i in range(len(slots) - 1):
                gap = slots[i + 1] - slots[i] - 1
                if gap > 0:
                    teacher_gap += gap

    if teacher_day_slots:
        teacher_gap /= (len(teacher_day_slots) * max_periods_per_day)
    else:
        teacher_gap = 0.0

    # =========================================================
    # 3️⃣ ROOM WASTE (0–1 SCALE)
    # =========================================================

    room_waste = 0.0

    for enrollment_id, room_id, _, _ in chromosome:
        group_id = enrollments[enrollment_id].group_id
        room = classrooms[room_id]
        group = groups[group_id]

        diff = abs(room.capacity - len(group.students)) / room.capacity
        room_waste += diff ** 2

    room_waste /= total_sessions

    # =========================================================
    # 4️⃣ TEACHER DISSATISFACTION (CLEANED — NO SAME-DAY LOGIC)
    # =========================================================

    teacher_dissatisfaction = 0.0
    day_load = {}
    preferred_count = 0

    for enrollment_id, _, start_slot, duration in chromosome:

        teacher_id = enrollments[enrollment_id].teacher_id
        teacher = teachers[teacher_id]

        day = slot_day_map[start_slot]
        day_load[day] = day_load.get(day, 0) + 1

        for t in range(start_slot, start_slot + duration):
            if t not in slot_day_map:
                continue

            if t in teacher.slot_preferences:
                rank = teacher.slot_preferences[t]
                teacher_dissatisfaction += (rank - 1) * 0.5
                preferred_count += 1
            else:
                teacher_dissatisfaction += 2

    loads = list(day_load.values())

    if len(loads) > 1:
        avg = sum(loads) / len(loads)
        day_variance = sum((x - avg) ** 2 for x in loads) / len(loads)
        day_variance /= max(loads)
    else:
        day_variance = 0.0

    teacher_dissatisfaction /= total_sessions

    preference_score = preferred_count / total_sessions if total_sessions else 0.0

    teacher_dissatisfaction = (
        teacher_dissatisfaction
        + 0.2 * day_variance
        - 0.2 * preference_score
    )

    teacher_dissatisfaction = max(0.0, teacher_dissatisfaction)

    # =========================================================
    # 5️⃣ SUBJECT DISTRIBUTION (FIXED)
    # ============================================================

    sd_score = subject_distribution_score(
        chromosome,
        enrollments,
        slot_day_map
    )

    # =========================================================
    # RETURN
    # ============================================================

    return (
        student_gap,
        teacher_gap,
        room_waste,
        teacher_dissatisfaction,
        sd_score
    )