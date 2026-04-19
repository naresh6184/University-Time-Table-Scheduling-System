from fastapi import HTTPException
from sqlalchemy.orm import Session
from backend.database.models.classroom import ClassroomModel

def create_classroom(db: Session, classroom_data):
    if db.query(ClassroomModel).filter(ClassroomModel.name == classroom_data.name).first():
        raise HTTPException(status_code=400, detail=f"A classroom with name '{classroom_data.name}' already exists")
    
    classroom = ClassroomModel(
        name=classroom_data.name,
        capacity=classroom_data.capacity,
        room_type=classroom_data.room_type
    )
    db.add(classroom)
    db.commit()
    db.refresh(classroom)
    return classroom

def get_all_classrooms(db: Session):
    return db.query(ClassroomModel).all()

from sqlalchemy.exc import IntegrityError
from backend.database.models.session_entities import SessionClassroomModel

def delete_classroom(db: Session, room_id: int):
    room = db.query(ClassroomModel).filter(ClassroomModel.room_id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Classroom not found")

    # 1. Delete session_classroom junction entries
    db.query(SessionClassroomModel).filter(SessionClassroomModel.room_id == room_id).delete(synchronize_session=False)

    # 2. Delete timetable entries referencing this room
    from backend.database.models.timetable_entry import TimetableEntryModel
    db.query(TimetableEntryModel).filter(TimetableEntryModel.room_id == room_id).delete(synchronize_session=False)

    # 3. Delete the classroom itself
    try:
        db.delete(room)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Cannot delete this classroom because it is still referenced by other data. Please remove related enrollments or timetable data first."
        )

def update_classroom(db: Session, room_id: int, classroom_data):
    if hasattr(classroom_data, 'name') and classroom_data.name:
        existing = db.query(ClassroomModel).filter(ClassroomModel.name == classroom_data.name, ClassroomModel.room_id != room_id).first()
        if existing:
            raise HTTPException(status_code=400, detail=f"A classroom with name '{classroom_data.name}' already exists")
            
    room = db.query(ClassroomModel).filter(ClassroomModel.room_id == room_id).first()
    if room:
        for key, value in classroom_data.model_dump(exclude_unset=True).items():
            setattr(room, key, value)
        db.commit()
        db.refresh(room)
    return room
