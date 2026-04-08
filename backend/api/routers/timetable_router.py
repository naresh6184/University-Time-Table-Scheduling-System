from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from backend.database.session import SessionLocal, get_db
from backend.bridge.runner import run_scheduler
import logging

# Setup logger for Uvicorn visibility
logger = logging.getLogger("uvicorn.error")

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

from backend.api.services.timetable_queries import (
    get_branch_timetable,
    get_teacher_timetable,
    get_group_timetable,
    get_room_timetable,
    delete_timetable_version,
    mark_version_as_duplicate
)

from backend.api.services.timetable_service import (
    get_branch_grid,
    get_group_grid,
    get_teacher_grid,
    get_room_grid,
    list_versions,
    activate_version,
    get_conflicts,
    get_institute_timetable,
    get_slots,
    reset_system
)

from backend.api.schemas.timetable_schema import (
    GroupTimetableResponse,
    TeacherTimetableResponse,
    RoomTimetableResponse,
    GridResponse,
    BranchTimetableResponse,
    ConflictResponse,
    InstituteTimetableResponse,
    PartitionUpdate
)
from backend.api.schemas.timetable_version_schema import TimetableVersionListResponse
from backend.api.utils.timetable_utils import detect_duplicate_version
from backend.api.utils.excel_exporter import export_timetables_to_excel
from backend.api.services.timetable_queries import get_resolved_version

router = APIRouter(prefix="/timetable", tags=["Timetable"])


# ------------------------------------------------
# Branch timetable
# ------------------------------------------------
@router.get("/branch/{branch_id}", response_model=BranchTimetableResponse)
def branch_timetable(branch_id: int, db: Session = Depends(get_db)):

    entries = get_branch_timetable(db, branch_id)

    timetable = [
        {
            "slot_id": e.slot_id,
            "subject": getattr(e, "subject_name", None),
            "group": getattr(e, "group_name", None),
            "teacher": getattr(e, "teacher_id", None),
            "room_id": e.room_id
        }
        for e in entries
    ]

    return {
        "branch_id": branch_id,
        "timetable": timetable
    }


# ------------------------------------------------
# Teacher timetable
# ------------------------------------------------
@router.get("/teacher/{teacher_id}", response_model=TeacherTimetableResponse)
def teacher_timetable(teacher_id: int, db: Session = Depends(get_db)):

    rows = get_teacher_timetable(db, teacher_id)

    timetable = [
        {
            "slot_id": r.slot_id,
            "subject": r.subject_name,
            "group": r.group_name,
            "room_id": r.room_id,
            "room_type": r.room_type
        }
        for r in rows
    ]

    return {
        "teacher_id": teacher_id,
        "timetable": timetable
    }


# ------------------------------------------------
# Group timetable
# ------------------------------------------------
@router.get("/group/{group_id}", response_model=GroupTimetableResponse)
def group_timetable(group_id: int, db: Session = Depends(get_db)):

    rows = get_group_timetable(db, group_id)

    timetable = [
        {
            "slot_id": r.slot_id,
            "subject": r.subject_name,
            "teacher": r.teacher_id,
            "room_id": r.room_id,
            "room_type": r.room_type
        }
        for r in rows
    ]

    return {
        "group_id": group_id,
        "timetable": timetable
    }


# ------------------------------------------------
# Room timetable
# ------------------------------------------------
@router.get("/room/{room_id}", response_model=RoomTimetableResponse)
def room_timetable(room_id: int, db: Session = Depends(get_db)):

    rows = get_room_timetable(db, room_id)

    timetable = [
        {
            "slot_id": r.slot_id,
            "subject": r.subject_name,
            "group": r.group_name,
            "teacher": r.teacher_id
        }
        for r in rows
    ]

    return {
        "room_id": room_id,
        "timetable": timetable
    }


# ------------------------------------------------
# Grid endpoints
# ------------------------------------------------
@router.get("/group/{group_id}/grid", response_model=GridResponse)
def group_grid(group_id: int, version_id: int | None = Query(None), db: Session = Depends(get_db)):
    return get_group_grid(db, group_id, version_id)

@router.get("/group/{group_id}/export")
def export_group_grid(group_id: int, version_id: int | None = Query(None), db: Session = Depends(get_db)):
    grid_data = get_group_grid(db, group_id, version_id)
    group_name = db.query(GroupModel.name).filter(GroupModel.group_id == group_id).scalar() or f"Group {group_id}"
    
    tt_info = {
        "entity_name": group_name,
        "context": "group",
        "grid_data": grid_data["grid"],
        "periods": grid_data["periods"],
        "assignments": grid_data.get("assignments", [])
    }
    
    excel_stream = export_timetables_to_excel([tt_info], format_type="tabs")
    return StreamingResponse(excel_stream, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers={"Content-Disposition": f"attachment; filename=timetable_group_{group_id}.xlsx"})


@router.get("/teacher/{teacher_id}/grid", response_model=GridResponse)
def teacher_grid(teacher_id: int, version_id: int | None = Query(None), db: Session = Depends(get_db)):
    return get_teacher_grid(db, teacher_id, version_id)

@router.get("/teacher/{teacher_id}/export")
def export_teacher_grid(teacher_id: int, version_id: int | None = Query(None), db: Session = Depends(get_db)):
    grid_data = get_teacher_grid(db, teacher_id, version_id)
    teach_name = db.query(TeacherModel.name).filter(TeacherModel.teacher_id == teacher_id).scalar() or f"Teacher {teacher_id}"
    
    tt_info = {
        "entity_name": teach_name,
        "context": "teacher",
        "grid_data": grid_data["grid"],
        "periods": grid_data["periods"],
        "assignments": grid_data.get("assignments", [])
    }
    
    excel_stream = export_timetables_to_excel([tt_info], format_type="tabs")
    return StreamingResponse(excel_stream, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers={"Content-Disposition": f"attachment; filename=timetable_teacher_{teacher_id}.xlsx"})


@router.get("/room/{room_id}/grid", response_model=GridResponse)
def room_grid(room_id: int, version_id: int | None = Query(None), db: Session = Depends(get_db)):
    return get_room_grid(db, room_id, version_id)

@router.get("/room/{room_id}/export")
def export_room_grid(room_id: int, version_id: int | None = Query(None), db: Session = Depends(get_db)):
    grid_data = get_room_grid(db, room_id, version_id)
    room_name = db.query(ClassroomModel.name).filter(ClassroomModel.room_id == room_id).scalar() or f"Room {room_id}"
    
    tt_info = {
        "entity_name": room_name,
        "context": "room",
        "grid_data": grid_data["grid"],
        "periods": grid_data["periods"],
        "assignments": grid_data.get("assignments", [])
    }
    
    excel_stream = export_timetables_to_excel([tt_info], format_type="tabs")
    return StreamingResponse(excel_stream, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers={"Content-Disposition": f"attachment; filename=timetable_room_{room_id}.xlsx"})
    
# ------------------------------------------------
# Branch
# ------------------------------------------------
@router.get("/branch/{branch_id}/grid", response_model=GridResponse)
def branch_grid(branch_id: int, version_id: int | None = Query(None), db: Session = Depends(get_db)):
    return get_branch_grid(db, branch_id, version_id)

@router.get("/branch/{branch_id}/export")
def export_branch_grid(branch_id: int, version_id: int | None = Query(None), db: Session = Depends(get_db)):
    grid_data = get_branch_grid(db, branch_id, version_id)
    branch_name = db.query(BranchModel.name).filter(BranchModel.branch_id == branch_id).scalar() or f"Branch {branch_id}"
    
    tt_info = {
        "entity_name": branch_name,
        "context": "branch",
        "grid_data": grid_data["grid"],
        "periods": grid_data["periods"],
        "assignments": grid_data.get("assignments", [])
    }
    
    excel_stream = export_timetables_to_excel([tt_info], format_type="tabs")
    return StreamingResponse(
        excel_stream, 
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 
        headers={"Content-Disposition": f"attachment; filename=timetable_branch_{branch_id}.xlsx"}
    )

# ------------------------------------------------
# Active Entities
# ------------------------------------------------
@router.get("/active-entities")
def active_entities(session_id: int = Query(...), version_id: int | None = Query(None), db: Session = Depends(get_db)):
    from backend.api.services.timetable_queries import get_active_entities
    return get_active_entities(db, session_id, version_id)

# ------------------------------------------------
# Export All
# ------------------------------------------------
@router.get("/export_all")
def export_all_timetables(
    entity_type: str = Query(..., description="group, teacher, or room"),
    format_type: str = Query("tabs", description="tabs or vertical"),
    session_id: int = Query(...),
    version_id: int | None = Query(None),
    db: Session = Depends(get_db)
):
    active_version = get_resolved_version(db, version_id, session_id)
    if not active_version:
        raise HTTPException(status_code=404, detail="No active version found")
        
    timetables = []
    
    if entity_type == "group":
        group_ids = db.query(EnrollmentModel.group_id).join(TimetableEntryModel, TimetableEntryModel.enrollment_id == EnrollmentModel.enrollment_id).filter(TimetableEntryModel.version_id == active_version.version_id).distinct().all()
        for (gid,) in group_ids:
            grid_data = get_group_grid(db, gid, active_version.version_id)
            gname = db.query(GroupModel.name).filter(GroupModel.group_id == gid).scalar() or f"Group {gid}"
            timetables.append({"entity_name": gname, "context": "group", "grid_data": grid_data["grid"], "periods": grid_data["periods"], "assignments": grid_data.get("assignments", [])})
    elif entity_type == "teacher":
        teacher_ids = db.query(EnrollmentModel.teacher_id).join(TimetableEntryModel, TimetableEntryModel.enrollment_id == EnrollmentModel.enrollment_id).filter(TimetableEntryModel.version_id == active_version.version_id).distinct().all()
        for (tid,) in teacher_ids:
            grid_data = get_teacher_grid(db, tid, active_version.version_id)
            tname = db.query(TeacherModel.name).filter(TeacherModel.teacher_id == tid).scalar() or f"Teacher {tid}"
            timetables.append({"entity_name": tname, "context": "teacher", "grid_data": grid_data["grid"], "periods": grid_data["periods"], "assignments": grid_data.get("assignments", [])})
    elif entity_type == "room":
        room_ids = db.query(TimetableEntryModel.room_id).filter(TimetableEntryModel.version_id == active_version.version_id).distinct().all()
        for (rid,) in room_ids:
            grid_data = get_room_grid(db, rid, active_version.version_id)
            rname = db.query(ClassroomModel.name).filter(ClassroomModel.room_id == rid).scalar() or f"Room {rid}"
            timetables.append({"entity_name": rname, "context": "room", "grid_data": grid_data["grid"], "periods": grid_data["periods"], "assignments": grid_data.get("assignments", [])})
    elif entity_type == "branch":
        from backend.database.models import StudentModel, GroupStudentModel
        active_group_ids = [gid for (gid,) in db.query(EnrollmentModel.group_id).join(TimetableEntryModel, TimetableEntryModel.enrollment_id == EnrollmentModel.enrollment_id).filter(TimetableEntryModel.version_id == active_version.version_id).distinct().all()]
        branch_ids = [bid for (bid,) in db.query(StudentModel.branch_id).join(GroupStudentModel).filter(GroupStudentModel.group_id.in_(active_group_ids)).distinct().all() if bid is not None]
        for bid in branch_ids:
            grid_data = get_branch_grid(db, bid, active_version.version_id)
            bname = db.query(BranchModel.name).filter(BranchModel.branch_id == bid).scalar() or f"Branch {bid}"
            timetables.append({"entity_name": bname, "context": "branch", "grid_data": grid_data["grid"], "periods": grid_data["periods"], "assignments": grid_data.get("assignments", [])})
    else:
        raise HTTPException(status_code=400, detail="Invalid entity_type")
    
    if not timetables:
        raise HTTPException(status_code=404, detail="No timetables found")
        
    excel_stream = export_timetables_to_excel(timetables, format_type)
    return StreamingResponse(
        excel_stream, 
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 
        headers={"Content-Disposition": f"attachment; filename=all_{entity_type}_timetables.xlsx"}
    )



# ------------------------------------------------
# Versions
# ------------------------------------------------
@router.get("/versions", response_model=TimetableVersionListResponse)
def get_versions(session_id: int | None = Query(None), db: Session = Depends(get_db)):
    if session_id is None:
        raise HTTPException(status_code=400, detail="Active session required to access this resource.")
    return list_versions(db, session_id)


# ------------------------------------------------
# Activate version
# ------------------------------------------------
@router.post("/version/{version_id}/activate")
def activate_timetable(version_id: int, db: Session = Depends(get_db)):
    return activate_version(db, version_id)


# ------------------------------------------------
# Delete version
# ------------------------------------------------
@router.delete("/version/{version_id}")
def delete_version_endpoint(version_id: int, db: Session = Depends(get_db)):
    success = delete_timetable_version(db, version_id)
    if not success:
        raise HTTPException(status_code=404, detail="Version not found")
    return {"status": "success", "message": "Version deleted"}


# ------------------------------------------------
# Conflict detection
# ------------------------------------------------
@router.get("/conflicts", response_model=ConflictResponse)
def timetable_conflicts(version: int = None, db: Session = Depends(get_db)):
    return get_conflicts(db, version_id=version)


# ------------------------------------------------
# Detailed Conflict detection (with enrollment info)
# ------------------------------------------------
@router.get("/version/{version_id}/conflicts")
def version_conflicts_detailed(version_id: int, db: Session = Depends(get_db)):
    from backend.api.services.timetable_queries import get_detailed_conflicts
    return get_detailed_conflicts(db, version_id)


# ------------------------------------------------
# Institute timetable
# ------------------------------------------------
@router.get("/institute", response_model=InstituteTimetableResponse)
def institute_timetable(session_id: int | None = Query(None), db: Session = Depends(get_db)):
    if session_id is None:
        raise HTTPException(status_code=400, detail="Active session required to access this resource.")
    return get_institute_timetable(db, session_id)


# ------------------------------------------------
# Generate timetable (FIXED)
# ------------------------------------------------
@router.post("/generate")
def generate_timetable(
    session_id: int | None = Query(None),
    population: int | None = Query(None),
    generations: int | None = Query(None),
    db: Session = Depends(get_db)
):
    if session_id is None:
        raise HTTPException(status_code=400, detail="Active session required to access this resource.")
    logger.info(">>> API REQUEST RECEIVED: /timetable/generate")
    try:
        pop_size = population if population is not None else 100
        gen_count = generations if generations is not None else 200
        version_id, is_feasible, breakdown = run_scheduler(db, session_id, population_size=pop_size, generations=gen_count)

        if is_feasible:
            # Check for exactly identical existing timetables
            duplicate_v_id = detect_duplicate_version(db, session_id, version_id)
            if duplicate_v_id is not None:
                # Retain the version info, but purge its redundant timetable rows and point it to the duplicate.
                mark_version_as_duplicate(db, version_id, duplicate_v_id)
                return {
                    "status": "duplicate",
                    "message": f"Identical to Version v.{duplicate_v_id}",
                    "version_id": version_id  # Returning the new version but flagged as duplicate physically. Or should we return duplicate_v_id directly?
                    # The frontend should redirect to the duplicate_v_id (the original) when showing "same as".
                    # Let's add duplicate_of parameter to the response so the frontend knows what happened.
                }

            return {
                "status": "success",
                "message": "Timetable generated successfully",
                "version_id": version_id
            }
        else:
            return {
                "status": "conflicts",
                "message": "Timetable generated with conflicts",
                "version_id": version_id,
                "violations": breakdown
            }

    except ValueError as e:
        # ✅ Infeasible case (NO 500 error)
        return {
            "status": "infeasible",
            "message": str(e)
        }

    except Exception as e:
        import traceback
        logger.error(f"[GENERATE ERROR] {type(e).__name__}: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(
            status_code=500,
            detail=f"{type(e).__name__}: {e}"
        )


# ------------------------------------------------
# Slots
# ------------------------------------------------
@router.get("/slots")
def list_slots(db: Session = Depends(get_db)):
    return get_slots(db)


# ------------------------------------------------
# Reset system
# ------------------------------------------------
@router.post("/reset")
def reset_system_endpoint(session_id: int | None = Query(None), db: Session = Depends(get_db)):
    if session_id is None:
        raise HTTPException(status_code=400, detail="Active session required to access this resource.")
    return reset_system(db, session_id)


# ------------------------------------------------
# Cancel Generation
# ------------------------------------------------
@router.post("/cancel")
def cancel_generation(session_id: int | None = Query(None)):
    if session_id is None:
        raise HTTPException(status_code=400, detail="Active session required to cancel.")
    
    from backend.bridge.runner import active_cancellations
    if session_id in active_cancellations:
        active_cancellations[session_id].set()
        return {"status": "success", "message": "Cancellation signal sent."}
    else:
        return {"status": "ignored", "message": "No active generation found for this session."}

# ------------------------------------------------
# Generation Status
# ------------------------------------------------
@router.get("/generate/status")
def generation_status(session_id: int | None = Query(None)):
    if session_id is None:
        raise HTTPException(status_code=400, detail="Active session required.")
    
    from backend.bridge.runner import generation_progress
    state = generation_progress.get(session_id)
    if not state:
        return {"status": "Idle"}
    return state