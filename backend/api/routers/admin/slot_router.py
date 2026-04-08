from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from backend.database.session import get_db
from backend.api.schemas.slot_schema import SlotConfigureRequest
from backend.api.services.slot_service import configure_slots, get_all_slots

router = APIRouter(
    prefix="/admin/slots",
    tags=["Admin - Slots Config"]
)

@router.get("/config")
def get_current_slots(session_id: int = None, db: Session = Depends(get_db)):
    slots = get_all_slots(db, session_id)
    # Reconstruct config from slots
    if not slots:
        start_hour = 9
        end_hour = 18
        working_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        
        default_slots = []
        for i, day in enumerate(working_days):
            for p in range(1, (end_hour - start_hour) + 1):
                if p == 5: continue # 13:00 - 14:00 is LUNCH by default
                h = start_hour + p - 1
                default_slots.append({
                    "slot_id": -(i * 100 + p), # Unique negative ID for template
                    "day": day,
                    "period": p,
                    "start": f"{h:02d}:00",
                    "end": f"{h+1:02d}:00",
                    "status": 1
                })
                
        return {
            "start_hour": start_hour,
            "end_hour": end_hour,
            "working_days": working_days,
            "slots": default_slots
        }
    
    days_set = sorted(list(set(s.day for s in slots)))
    min_hour = 24
    max_hour = 0
    
    for s in slots:
        start_h = int(s.start_time.split(":")[0])
        end_h = int(s.end_time.split(":")[0])
        if start_h < min_hour: min_hour = start_h
        if end_h > max_hour: max_hour = end_h

    # 51. Reconstruct days order & time range from DB
    all_days_ordered = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    active_days_in_db = set(s.day for s in slots if getattr(s, 'status', 1) != 0)

    # We keep days that actually have active or blocked data (status != 0)
    working_days = [d for d in all_days_ordered if d in active_days_in_db]

    # Ensure we include at least the 9-18 range
    final_start = min(min_hour, 9)
    final_end = max(max_hour, 18)

    return {
        "start_hour": final_start,
        "end_hour": final_end,
        "working_days": working_days,
        "slots": [{"slot_id": s.slot_id, "day": s.day, "period": s.period_number, "start": s.start_time, "end": s.end_time, "status": getattr(s, 'status', 1)} for s in slots]
    }


@router.post("/configure")
def update_slot_config(data: SlotConfigureRequest, session_id: int, db: Session = Depends(get_db)):
    return configure_slots(db, data, session_id)

