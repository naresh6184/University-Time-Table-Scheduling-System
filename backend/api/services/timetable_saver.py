from sqlalchemy.orm import Session
from backend.database.models.timetable_version import TimetableVersionModel
from backend.database.models.timetable_entry import TimetableEntryModel
from backend.database.models.timetable_conflict import TimetableConflictModel
from backend.api.services.bootstrap_service import CONFLICT_KEY_TO_TYPE_ID
import json


def save_timetable(
    db: Session,
    session_id: int,
    violation: int,
    soft_score: float,
    chromosome: list,
    enrollments_data,
    reverse_slot_map,
    population_size,
    generations,
    is_feasible=True,
    conflict_log=None,
    detailed_conflicts=None
):

    # Calculate metrics
    best_violation = violation

    # Deactivate previous active version ONLY if new one is feasible (scoped to session)
    if is_feasible:
        db.query(TimetableVersionModel)\
        .filter(TimetableVersionModel.is_active == True, TimetableVersionModel.session_id == session_id)\
        .update({"is_active": False})

    # Serialize conflict log to JSON string
    conflict_json_str = None
    if conflict_log:
        conflict_json_str = json.dumps(conflict_log)

    # Create new version
    new_version = TimetableVersionModel(
        session_id=session_id,
        population_size=population_size,
        generations=generations,
        best_violation=best_violation,
        best_soft_score=soft_score,
        is_active=is_feasible,
        conflict_json=conflict_json_str
    )

    db.add(new_version)
    db.commit()
    db.refresh(new_version)

    # Save each gene
    print("Chromosome length:", len(chromosome))

    enrollments = [g[0] for g in chromosome]
    print("Unique enrollments:", len(set(enrollments)))
    for gene in chromosome:
        # expanded_id, room_id, start_slot, duration
        expanded_id, room_id, start_slot, duration = gene
        actual_enrollment_id = enrollments_data[expanded_id].enrollment_id

        if start_slot not in reverse_slot_map:
            continue
        slot_id = reverse_slot_map[start_slot]

        entry = TimetableEntryModel(
            version_id=new_version.version_id,
            enrollment_id=actual_enrollment_id,
            room_id=room_id,
            slot_id=slot_id,
            duration=duration
        )
        db.add(entry)

    # -------------------------
    # PERSIST DETAILED CONFLICTS
    # -------------------------
    if detailed_conflicts:
        for detail in detailed_conflicts:
            type_id = CONFLICT_KEY_TO_TYPE_ID.get(detail.get("key"))
            if type_id is None:
                continue  # Unknown conflict key — skip

            conflict_record = TimetableConflictModel(
                version_id=new_version.version_id,
                session_id=session_id,
                conflict_type_id=type_id,
                conflict_level="Hard",
                entity_id=detail.get("entity_id"),
                entity_name=detail.get("entity_name"),
                slot_label=detail.get("slot_label"),
                primary_enrollment_id=detail.get("primary_enrollment_id"),
                conflicting_enrollment_id=detail.get("conflicting_enrollment_id"),
            )
            db.add(conflict_record)

    db.commit()

    return new_version.version_id