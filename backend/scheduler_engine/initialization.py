import random
from typing import Dict, List, Tuple

from backend.scheduler_engine.entities import *

# (enrollment_id, room_id, start_slot, duration)
Gene = Tuple[int, int, int, int]


def generate_random_schedule(
    enrollments,
    teachers,
    classrooms,
    subjects,
    groups,
    total_slots,
    slot_day_map,
    slot_period_map
):
    """
    Creates a random initial schedule by assigning each EXPANDED enrollment 
    (one session) to a valid room and timeslot.
    """

    chromosome = []

    for expanded_id, enrollment in enrollments.items():

        teacher = teachers[enrollment.teacher_id]
        subject = subjects[enrollment.subject_id]
        group   = groups[enrollment.group_id]

        # Each engine enrollment now represents exactly ONE session/block
        duration = enrollment.duration

        # -------- VALID ROOMS --------
        # Prefer rooms with enough capacity, fall back to any room of matching type
        valid_rooms = [
            room_id
            for room_id, room in classrooms.items()
            if room.room_type == subject.subject_type
            and room.capacity >= len(group.students)
        ]

        if not valid_rooms:
            # Fallback: any room of correct type regardless of capacity
            valid_rooms = [
                room_id
                for room_id, room in classrooms.items()
                if room.room_type == subject.subject_type
            ]

        if not valid_rooms:
            continue

        room_id = random.choice(valid_rooms)

        # -------- VALID START SLOTS --------
        valid_start_slots = []
        
        # Check if the session stays within the same day
        for slot in teacher.available_slots:
            if slot + duration <= total_slots:
                # Ensure start and end slots are on the same day AND don't cross lunch
                if slot_day_map[slot] == slot_day_map[slot + duration - 1]:
                    # 🔥 NO LUNCH CROSSING IN INITIALIZATION
                    # period_number is 1-indexed. P4 is 4, P5 is 5.
                    p_start = slot_period_map[slot]
                    p_end = slot_period_map[slot + duration - 1]
                    if not (p_start <= 4 and p_end >= 5):
                        valid_start_slots.append(slot)

        if not valid_start_slots:
            # Fallback if no slot fits perfectly (try any valid slots)
            valid_start_slots = [
                s for s in teacher.available_slots 
                if s + duration <= total_slots
            ]

        if not valid_start_slots:
            continue

        start_slot = random.choice(valid_start_slots)

        chromosome.append(
            (expanded_id, room_id, start_slot, duration)
        )

    return chromosome
