from sqlalchemy.orm import Session
import sys
import os
import time
import random

from backend.bridge.data_loader import load_engine_data
from backend.scheduler_engine.nsga2 import run_nsga2
from backend.api.services.timetable_saver import save_timetable
import threading
import logging

# Setup logger for Uvicorn visibility
logger = logging.getLogger("uvicorn.error")

active_cancellations: dict[int, threading.Event] = {}
generation_progress: dict[int, dict] = {}


def debug_print_daywise_table(
    chromosome,
    enrollments,
    slot_day_map,
    slot_period_map,
    num_periods=8
):
    """
    Prints timetable in clean day-wise table format:
    Mon → Tue → Wed → Thu → Fri → Sat → Sun
    """

    # -------------------------------------------------
    # Build structure: day → period → room → lecture
    # -------------------------------------------------
    day_view = {}

    for e_id, room_id, start, duration in chromosome:
        for t in range(start, start + duration):

            day = slot_day_map[t]
            period = slot_period_map[t]

            e = enrollments[e_id]

            text = f"S{e.subject_id}-G{e.group_id}-T{e.teacher_id}"

            day_view.setdefault(day, {}) \
                    .setdefault(period, {})[room_id] = text

    # -------------------------------------------------
    # Custom Day Order
    # -------------------------------------------------
    DAY_ORDER = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    # -------------------------------------------------
    # Print
    # -------------------------------------------------
    for day in DAY_ORDER:

        if day not in day_view:
            continue

        print(f"\n========= DAY {day} =========\n")

        # Header
        print("Period → ", end="")
        for p in range(num_periods):
            print(f"P{p:^10}", end="")
        print()

        print("-" * (12 * (num_periods + 1)))

        # Collect all rooms used that day
        rooms = set()
        for periods in day_view[day].values():
            rooms.update(periods.keys())

        # Print rows
        for room in sorted(rooms):
            print(f"Room {room:<5} ", end="")

            for p in range(num_periods):
                val = day_view[day].get(p, {}).get(room, "--")
                print(f"{val:^12}", end="")

            print()


def run_scheduler(db: Session, session_id: int, population_size: int = 100, generations: int = 200):
    cancel_event = threading.Event()
    active_cancellations[session_id] = cancel_event
    
    generation_progress[session_id] = {
        "status": "Initializing",
        "attempt": 1,
        "max_attempts": 5,
        "generation": 0,
        "max_generations": generations,
        "best_violation": None,
        "breakdown": None,
        "is_feasible": False,
        "conflict_logs": [],
        "feasibility_info": None
    }

    try:
        # -------------------------
        # LOAD DATA (UPDATED)
        # -------------------------
        # 1. Database Load
        data = load_engine_data(db, session_id)
        (
            branches, students, groups, teachers, classrooms, subjects,
            enrollments, group_conflicts, total_slots, reverse_slot_map,
            slot_day_map, slot_period_map, total_required, capacity, OVERALL_FEASIBLE
        ) = data

        logger.info("")
        logger.info("  Engine started")
        for ctype in ["theory", "lab"]:
            req = total_required.get(ctype, 0)
            cap = capacity.get(ctype, 0)
            status = "OK" if cap >= req else "!! INFEASIBLE"
            logger.info(f"  {ctype.capitalize():<8}: Required={req}  Available={cap}  [{status}]")
        logger.info("")

        generation_progress[session_id]["feasibility_info"] = {
            "theory": {"required": total_required.get("theory", 0), "available": capacity.get("theory", 0)},
            "lab": {"required": total_required.get("lab", 0), "available": capacity.get("lab", 0)}
        }

        if not enrollments:
            raise ValueError("No enrollments found. Nothing to schedule.")

        # -------------------------
        # 🚨 FEASIBILITY CHECK (IMPORTANT)
        # -------------------------
        if not OVERALL_FEASIBLE:
            msg_parts = []
            for t, req in total_required.items():
                cap = capacity.get(t, 0)
                if req > cap:
                    msg_parts.append(f"{t.capitalize()} (Required: {req}, Capacity: {cap})")
            
            raise ValueError(
                f"Infeasible data: Not enough capacity for "
                f"{', '.join(msg_parts)}. Increase slots/rooms or reduce load."
            )

        # -------------------------
        # NSGA-II PARAMETERS (Quick Check)
        # -------------------------
        max_attempts = 5
        
        best_overall_solution = None

        # -------------------------
        # RUN NSGA-II (MULTI-START)
        # -------------------------
        for attempt in range(1, max_attempts + 1):
            generation_progress[session_id]["attempt"] = attempt
            generation_progress[session_id]["status"] = "Generating"
            generation_progress[session_id]["generation"] = 0
            
            if cancel_event.is_set():
                logger.info("  Engine cancelled by user before attempt started.")
                generation_progress[session_id]["status"] = "Cancelled"
                break

            # RESEED for each attempt to ensure different random paths
            random.seed(os.getpid() + attempt + int(time.time() * 1000))
            
            logger.info(f"  --- Attempt {attempt}/{max_attempts} (pop={population_size}, gens={generations}) ---")
            
            def progress_cb(gen, best_violation, best_chromosome):
                generation_progress[session_id]["generation"] = gen + 1
                
                raw_count = 0
                temp_logs = []
                if best_violation > 0:
                    from backend.scheduler_engine.constraints import constraint_violation
                    _, bd = constraint_violation(
                        best_chromosome,
                        enrollments, teachers, classrooms, groups, subjects, group_conflicts,
                        total_slots, slot_day_map, slot_period_map, return_breakdown=True
                    )
                    weights = {
                        "invalid_timeslot": 100, "day_boundary_conflict": 500, "lunch_break_conflict": 100000,
                        "same_day_duplicate": 1000, "missing_enrollments": 1000, "teacher_conflict": 10,
                        "room_conflict": 10, "group_conflict": 10, "student_overlap": 5,
                        "availability": 1, "capacity": 1, "type_mismatch": 1
                    }
                    labels = {
                        "teacher_conflict": "Teacher Overlap",
                        "room_conflict": "Room Overlap",
                        "group_conflict": "Group Double-Book",
                        "student_overlap": "Student Overlap",
                        "day_boundary_conflict": "Crosses Day Boundary",
                        "lunch_break_conflict": "Crosses Lunch Break",
                        "same_day_duplicate": "Same-Day Duplicate",
                        "missing_enrollments": "Unplaced Classes"
                    }
                    for k, v in bd.items():
                        if v > 0:
                            count = v // weights.get(k, 1)
                            raw_count += count
                            if count > 0:
                                temp_logs.append({"type": labels.get(k, k.replace("_", " ").capitalize()), "count": count})
                
                generation_progress[session_id]["best_violation"] = raw_count
                generation_progress[session_id]["conflict_logs"] = temp_logs
            
            final_population = run_nsga2(
                population_size,
                generations,
                enrollments,
                teachers,
                classrooms,
                subjects,
                groups,
                group_conflicts,
                total_slots,
                slot_day_map,
                slot_period_map,
                cancel_event=cancel_event,
                progress_callback=progress_cb
            )

            current_best = min(final_population, key=lambda x: x.violation)
            
            if best_overall_solution is None or current_best.violation < best_overall_solution.violation:
                best_overall_solution = current_best

            if best_overall_solution.violation == 0 or cancel_event.is_set():
                if cancel_event.is_set():
                    logger.info(f"  Done. Engine cancelled. Using best solution found so far.")
                else:
                    logger.info(f"  Done. Feasible solution found.")
                break
            else:
                logger.info(f"  Attempt {attempt} ended: best V={current_best.violation}. Retrying...")

        best_solution = best_overall_solution

        # -------------------------
        # EDGE CASE: Cancelled before any attempt ran
        # -------------------------
        if best_solution is None:
            logger.info("  No solution was produced (cancelled before first attempt).")
            generation_progress[session_id]["status"] = "Cancelled"
            return None, False, {}

        # -------------------------
        # CHECK FEASIBILITY
        # -------------------------
        is_feasible = (best_solution.violation == 0)
        breakdown = {}
        detailed_conflicts = []  # Per-instance conflict detail dicts

        if not is_feasible:
            from backend.scheduler_engine.constraints import constraint_violation
            _, breakdown = constraint_violation(
                best_solution.chromosome,
                enrollments,
                teachers,
                classrooms,
                groups,
                subjects,
                group_conflicts,
                total_slots,
                slot_day_map,
                slot_period_map,
                return_breakdown=True
            )

            # Convert raw GA penalty score back into human-readable occurrence counts
            weights = {
                "invalid_timeslot": 100,
                "day_boundary_conflict": 500,
                "lunch_break_conflict": 100000,
                "same_day_duplicate": 1000,
                "missing_enrollments": 1000,
                "teacher_conflict": 10,
                "room_conflict": 10,
                "group_conflict": 10,
                "student_overlap": 5,
                "availability": 1,
                "capacity": 1,
                "type_mismatch": 1
            }

        # -------------------------
        # DETAILED CONFLICT CAPTURE (final reporting — always run)
        # -------------------------
        from backend.scheduler_engine.constraints import constraint_violation as cv_detail
        _, _, detailed_conflicts = cv_detail(
            best_solution.chromosome,
            enrollments,
            teachers,
            classrooms,
            groups,
            subjects,
            group_conflicts,
            total_slots,
            slot_day_map,
            slot_period_map,
            capture_details=True
        )

        # -------------------------
        # FINAL CONFLICT SUMMARY
        # -------------------------
        conflict_logs = []
        if not is_feasible:
            labels = {
                "teacher_conflict": "Teacher Overlap",
                "room_conflict": "Room Overlap",
                "group_conflict": "Group Double-Book",
                "student_overlap": "Student Overlap",
                "day_boundary_conflict": "Crosses Day Boundary",
                "lunch_break_conflict": "Crosses Lunch Break",
                "same_day_duplicate": "Same-Day Duplicate",
                "missing_enrollments": "Unplaced Classes"
            }
            logger.info("")
            logger.info("  Conflicts detected:")
            for k, v_raw in breakdown.items():
                if v_raw > 0:
                    weight = weights.get(k, 1)
                    count = v_raw // weight
                    label = labels.get(k, k.replace("_", " ").capitalize())
                    logger.info(f"    - {label:<22}: {count}")
                    conflict_logs.append({"type": label, "count": count})
            logger.info("")
            generation_progress[session_id]["status"] = "Completed with Conflicts"
        else:
            logger.info("  No conflicts. Timetable is feasible.")
            generation_progress[session_id]["status"] = "Completed Successfully"
            
        generation_progress[session_id]["is_feasible"] = is_feasible
        generation_progress[session_id]["conflict_logs"] = conflict_logs
        generation_progress[session_id]["breakdown"] = breakdown
        # Sync best_violation with the final conflict count so Generation Feed
        # and Version Card always display the same number.
        final_conflict_count = sum(item.get("count", 0) for item in conflict_logs)
        generation_progress[session_id]["best_violation"] = final_conflict_count

        # -------------------------
        # DEBUG PRINT
        # -------------------------
        # debug_print_daywise_table(
        #     best_solution.chromosome,
        #     enrollments,
        #     slot_day_map,
        #     slot_period_map
        # )

        # -------------------------
        # SAVE TIMETABLE
        # -------------------------
        version_id = save_timetable(
            db=db,
            session_id=session_id,
            # Persist conflict count (human-readable) instead of weighted GA penalty.
            violation=sum(item.get("count", 0) for item in conflict_logs),
            soft_score=sum(best_solution.objectives) if best_solution.objectives else 0.0,
            chromosome=best_solution.chromosome,
            enrollments_data=enrollments,
            reverse_slot_map=reverse_slot_map,
            population_size=population_size,
            generations=generations,
            is_feasible=is_feasible,
            conflict_log=conflict_logs,
            detailed_conflicts=detailed_conflicts
        )

        return version_id, is_feasible, breakdown

    finally:
        active_cancellations.pop(session_id, None)