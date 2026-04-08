import random
import time
from typing import Dict, List, Set, Tuple, Optional

from backend.scheduler_engine.entities import *

Gene = Tuple[int, int, int]  # (enrollment_id, room_id, timeslot_id)


# ------------------ Expand Enrollments ------------------

def expand_enrollments(enrollments: Dict[int, Enrollment],
                       subjects: Dict[int, Subject]):

    sessions = []

    for enrollment in enrollments.values():
        subject = subjects[enrollment.subject_id]

        for _ in range(subject.hours_per_week):
            sessions.append({
                "enrollment_id": enrollment.enrollment_id,
                "group_id": enrollment.group_id,
                "teacher_id": enrollment.teacher_id,
                "subject_id": enrollment.subject_id
            })

    return sessions


# ------------------ Improved Generator ------------------

def generate_feasible_schedule(
    enrollments: Dict[int, Enrollment],
    teachers: Dict[int, Teacher],
    classrooms: Dict[int, Classroom],
    groups: Dict[int, Group],
    subjects: Dict[int, Subject],
    group_conflicts: Dict[int, Set[int]],
    time_limit_seconds: int = 15
) -> Optional[List[Gene]]:

    start_time = time.time()

    sessions = expand_enrollments(enrollments, subjects)

    # -------- MOST-CONSTRAINED-FIRST ORDERING --------

    def session_difficulty(session):
        teacher = teachers[session["teacher_id"]]
        subject = subjects[session["subject_id"]]
        group = groups[session["group_id"]]

        valid_rooms = [
            r for r in classrooms.values()
            if r.capacity >= len(group.students)
            and r.room_type == subject.subject_type
        ]

        return len(valid_rooms) * len(teacher.available_slots)

    sessions.sort(key=session_difficulty)

    # -------- SCHEDULE STATE --------

    teacher_schedule: Dict[int, Set[int]] = {}
    room_schedule: Dict[int, Set[int]] = {}
    group_schedule: Dict[int, Set[int]] = {}

    chromosome: List[Gene] = []

    # -------- BACKTRACK --------

    def backtrack(index: int) -> bool:

        # Time guard
        if time.time() - start_time > time_limit_seconds:
            return False

        if index == len(sessions):
            return True

        session = sessions[index]
        enrollment_id = session["enrollment_id"]
        teacher_id = session["teacher_id"]
        group_id = session["group_id"]
        subject = subjects[session["subject_id"]]

        teacher = teachers[teacher_id]
        possible_slots = list(teacher.available_slots)

        valid_rooms = [
            room_id for room_id, room in classrooms.items()
            if room.capacity >= len(groups[group_id].students)
            and room.room_type == subject.subject_type
        ]

        # Shuffle for diversity
        random.shuffle(possible_slots)
        random.shuffle(valid_rooms)

        # Try limited combinations first (pruning)
        for timeslot in possible_slots:

            # Teacher conflict
            if timeslot in teacher_schedule.get(teacher_id, set()):
                continue

            # Group conflict
            if timeslot in group_schedule.get(group_id, set()):
                continue

            # Student overlap conflict
            conflict_found = False
            for conflict_group in group_conflicts.get(group_id, set()):
                if timeslot in group_schedule.get(conflict_group, set()):
                    conflict_found = True
                    break
            if conflict_found:
                continue

            for room_id in valid_rooms:

                # Room conflict
                if timeslot in room_schedule.get(room_id, set()):
                    continue

                # Commit
                chromosome.append((enrollment_id, room_id, timeslot))

                teacher_schedule.setdefault(teacher_id, set()).add(timeslot)
                group_schedule.setdefault(group_id, set()).add(timeslot)
                room_schedule.setdefault(room_id, set()).add(timeslot)

                if backtrack(index + 1):
                    return True

                # Undo
                chromosome.pop()
                teacher_schedule[teacher_id].remove(timeslot)
                group_schedule[group_id].remove(timeslot)
                room_schedule[room_id].remove(timeslot)

        return False

    success = backtrack(0)

    if success:
        return chromosome

    return None