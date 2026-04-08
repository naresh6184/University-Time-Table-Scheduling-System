from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from backend.database.session import get_db
from backend.database.models.timetable_entry import TimetableEntryModel
from backend.database.models.timetable_version import TimetableVersionModel
from backend.database.models.slot import SlotModel
from backend.database.models.enrollment import EnrollmentModel
from backend.database.models.subject import SubjectModel
from backend.database.models.teacher import TeacherModel
from backend.database.models.group import GroupModel
from backend.database.models.session_slot import SessionSlotModel

router = APIRouter()

# --- PROFESSIONAL PROFESSIONAL COLORS ---
SUB_COLORS = [
    "#E3F2FD", "#F3E5F5", "#E8F5E9", "#FFF3E0", "#F1F8E9", "#EFEBE9", "#ECEFF1", "#FCE4EC", "#E8EAF6"
]

def build_timetable_data(db: Session, version_id: int = None, mode="group"):
    # 1. Fetch Version
    if version_id:
        version = db.query(TimetableVersionModel).filter(TimetableVersionModel.version_id == version_id).first()
    else:
        version = db.query(TimetableVersionModel).filter(TimetableVersionModel.is_active == True).order_by(TimetableVersionModel.version_id.desc()).first()
    if not version: return None

    # 2. Load Maps (Session-Aware Slots)
    entries = db.query(TimetableEntryModel).filter(TimetableEntryModel.version_id == version.version_id).all()
    
    # Dynamically select slot model
    slot_model = SlotModel if version.session_id == -1 else SessionSlotModel
    slots = db.query(slot_model).filter(slot_model.session_id == version.session_id).all()

    # Build contiguous period index mapping (handles gaps like missing lunch period)
    day_periods = {}  # day -> sorted list of period_numbers
    for s in slots:
        day_periods.setdefault(s.day, set()).add(s.period_number)
    for day in day_periods:
        day_periods[day] = sorted(day_periods[day])

    period_to_idx = {}  # (day, period_number) -> contiguous 0-based index
    for day, periods in day_periods.items():
        for idx, pnum in enumerate(periods):
            period_to_idx[(day, pnum)] = idx

    slot_map = {}
    for s in slots:
        idx = period_to_idx.get((s.day, s.period_number), s.period_number - 1)
        slot_map[s.slot_id] = {"day": s.day, "period": idx}

    # Use a representative day for period time labels
    num_periods = max(len(p) for p in day_periods.values()) if day_periods else 9
    period_time_map = {}
    for s in slots:
        idx = period_to_idx.get((s.day, s.period_number))
        if idx is not None and idx not in period_time_map:
            period_time_map[idx] = f"{s.start_time}-{s.end_time}"
    
    enrollments_all = db.query(EnrollmentModel).all()
    enr_map = {e.enrollment_id: e for e in enrollments_all}
    subject_map = {s.subject_id: s for s in db.query(SubjectModel).all()}
    teacher_map = {t.teacher_id: t.name for t in db.query(TeacherModel).all()}
    group_map = {g.group_id: g for g in db.query(GroupModel).all()}
    
    sub_color_map = {s_id: SUB_COLORS[i % len(SUB_COLORS)] for i, s_id in enumerate(subject_map.keys())}
    
    # 3. Organize into Grid: Day -> RowLabel -> [Slots x num_periods]
    timetable = {}
    day_order = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    # Conflict Counters
    t_occ, g_occ, r_occ = {}, {}, {}
    for entry in entries:
        slot = slot_map.get(entry.slot_id)
        if not slot: continue
        d, p = slot["day"], slot["period"]
        en = enr_map.get(entry.enrollment_id)
        if not en: continue
        
        # Count occurrences per hour (for conflict detection)
        for offset in range(entry.duration or 1):
            curr_p = p + offset
            if curr_p < num_periods:
                t_occ[(d, curr_p, en.teacher_id)] = t_occ.get((d, curr_p, en.teacher_id), 0) + 1
                g_occ[(d, curr_p, en.group_id)] = g_occ.get((d, curr_p, en.group_id), 0) + 1
                r_occ[(d, curr_p, entry.room_id)] = r_occ.get((d, curr_p, entry.room_id), 0) + 1

    for entry in entries:
        slot = slot_map.get(entry.slot_id)
        if not slot: continue
        day, p = slot["day"], slot["period"]
        en = enr_map.get(entry.enrollment_id)
        if not en: continue
        
        row_label = (group_map[en.group_id].name if en.group_id in group_map else f"G{en.group_id}") if mode=="group" else f"Room {entry.room_id}"
        timetable.setdefault(day, {}).setdefault(row_label, [None] * num_periods)
        
        # Conflict Badges
        c_badges = []
        for offset in range(entry.duration or 1):
            curr_p = p + offset
            if curr_p < num_periods:
                if t_occ.get((day, curr_p, en.teacher_id), 0) > 1: c_badges.append("[Teacher]")
                if g_occ.get((day, curr_p, en.group_id), 0) > 1: c_badges.append("[Group]")
                if r_occ.get((day, curr_p, entry.room_id), 0) > 1: c_badges.append("[Room]")
        
        cell = {
            "text": f"<b>{subject_map[en.subject_id].name}</b><br>{teacher_map.get(en.teacher_id, '...')}<br>Room {entry.room_id}",
            "color": sub_color_map.get(en.subject_id, "#fff"),
            "duration": entry.duration or 1,
            "conflicts": " ".join(list(set(c_badges)))
        }
        # SPLIT LOGIC: sessions crossing lunch (idx 4) must be split for display
        parts = []
        if p < 4 and p + cell["duration"] > 4:
            dur_before = 4 - p
            dur_after = cell["duration"] - dur_before
            
            p1 = cell.copy(); p1["duration"] = dur_before
            parts.append((p, p1))
            
            p2 = cell.copy(); p2["duration"] = dur_after
            parts.append((4, p2))
        else:
            parts.append((p, cell))

        # Fill the grid for each part
        for start_p, p_cell in parts:
            if start_p >= num_periods: continue
            for offset in range(p_cell["duration"]):
                curr_p = start_p + offset
                if curr_p >= num_periods: break
                
                if timetable[day][row_label][curr_p] is None:
                    timetable[day][row_label][curr_p] = p_cell
                elif curr_p == start_p:
                    # In case of conflicts, we stack the text ONLY once per entry
                    timetable[day][row_label][curr_p]["text"] += "<hr>" + p_cell["text"]

    return {"grid": timetable, "day_order": day_order, "period_times": period_time_map, "version": version.version_id, "counts": {}, "num_periods": num_periods}

def render_table(data, title):
    if not data: return "<p>No data found.</p>"
    grid = data["grid"]
    p_times = data["period_times"]
    num_periods = data.get("num_periods", 9)
    html = f"<h3>{title}</h3>"

    for day in data["day_order"]:
        if day not in grid: continue
        html += f"<div class='day-wrapper'><div class='day-name'>{day}</div><table>"
        html += "<thead><tr><th style='width: 150px;'>Entity</th>"
        for p in range(4): html += f"<th>P{p+1}<br><span class='st'>{p_times.get(p,'')}</span></th>"
        html += "<th class='lc'>LUNCH</th>"
        for p in range(4, num_periods): html += f"<th>P{p+1}<br><span class='st'>{p_times.get(p,'')}</span></th>"
        html += "</tr></thead><tbody>"

        for row in sorted(grid[day].keys()):
            html += f"<tr><td class='rl'>{row}</td>"
            # Logic to handle colspan and ensure NO CLIP
            def render_segment(start, end):
                seg = ""; skip = 0
                for i in range(start, end):
                    if skip > 0: skip -= 1; continue
                    c = grid[day][row][i]
                    if not c: seg += "<td class='empty'>--</td>"
                    else:
                        dur = c["duration"]; ed = min(dur, end - i)
                        cs = f" colspan='{ed}'" if ed > 1 else ""
                        conf = f"<div class='cl'>{c['conflicts']}</div>" if c['conflicts'] else ""
                        seg += f"<td{cs} class='slot' style='background:{c['color']}'>{conf}{c['text']}</td>"
                        skip = ed - 1
                return seg
            html += render_segment(0, 4)
            html += "<td class='lc'>-</td>"
            html += render_segment(4, num_periods)
            html += "</tr>"
        html += "</tbody></table></div>"
    return html

@router.get("/view/html", response_class=HTMLResponse)
def get_view(version: int = None, db: Session = Depends(get_db)):
    gd = build_timetable_data(db, version, "group")
    rd = build_timetable_data(db, version, "room")
    v_id = gd["version"] if gd else "N/A"
    
    styles = """
    <style>
        body { font-family: 'Segoe UI', Arial; background: #f4f6f9; color: #333; padding: 20px; }
        .hdr { background: #1a237e; color: #fff; padding: 20px; border-radius: 8px; margin-bottom: 20px; text-align: center; }
        .tabs { display: flex; border-bottom: 2px solid #ddd; margin-bottom: 20px; }
        .tab-btn { padding: 12px 24px; cursor: pointer; border: 1px solid #ddd; border-bottom: none; background: #eee; margin-right: 4px; font-weight: bold; }
        .tab-btn.active { background: #fff; border-bottom: 2px solid #fff; margin-bottom: -2px; color: #1a237e; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        
        .day-wrapper { background: #fff; border: 1px solid #ddd; border-top: 4px solid #1a237e; border-radius: 6px; padding: 20px; margin-bottom: 30px; }
        .day-name { font-size: 1.4em; font-weight: bold; margin-bottom: 15px; color: #1a237e; }
        table { width: 100%; border-collapse: collapse; font-size: 0.9em; table-layout: fixed; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: center; overflow: hidden; }
        th { background: #f8f9fa; color: #555; }
        .st { font-size: 0.7em; font-weight: normal; color: #888; }
        .rl { font-weight: bold; background: #fafafa; }
        .empty { color: #ccc; }
        .lc { background: #fef9e7; width: 40px; font-size: 0.7em; }
        .slot { border-radius: 4px; line-height: 1.4; vertical-align: top; }
        .cl { font-size: 0.7em; color: #d32f2f; font-weight: bold; margin-bottom: 4px; }
    </style>
    """
    
    script = """
    <script>
        function openTab(n) {
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.getElementById(n).classList.add('active');
            event.currentTarget.classList.add('active');
        }
    </script>
    """
    
    body = f"""
    <div class='hdr'>
        <h2 style='margin:0;'>University Timetable Dashboard</h2>
        <small>Version v.{v_id} | Genetic Algorithm Results</small>
    </div>
    
    <div class='tabs'>
        <div class='tab-btn active' onclick="openTab('group_v')">Group-wise Table</div>
        <div class='tab-btn' onclick="openTab('room_v')">Room-wise Table</div>
    </div>
    
    <div id='group_v' class='tab-content active'>{render_table(gd, "Student Group Schedules")}</div>
    <div id='room_v' class='tab-content'>{render_table(rd, "Classroom Occupancy")}</div>
    """
    
    return HTMLResponse(content=f"<html><head>{styles}{script}</head><body>{body}</body></html>")