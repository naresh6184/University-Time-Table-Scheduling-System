from sqlalchemy.orm import Session
from backend.database.models.student import StudentModel


def create_student(db: Session, student_data):
    student = StudentModel(**student_data.model_dump())

    db.add(student)
    db.commit()
    db.refresh(student)

    return student


def get_all_students(db: Session):
    return db.query(StudentModel).all()

def search_students(db: Session, query: str):
    return db.query(StudentModel).filter(
        (StudentModel.name.ilike(f"%{query}%")) | (StudentModel.student_id.ilike(f"%{query}%"))
    ).all()


def update_student(db: Session, student_id: str, student_data):
    student = db.query(StudentModel).filter(StudentModel.student_id == student_id).first()
    if student:
        for key, value in student_data.model_dump(exclude_unset=True).items():
            setattr(student, key, value)
        db.commit()
        db.refresh(student)
    return student

def delete_student(db: Session, student_id: str):
    from fastapi import HTTPException
    from sqlalchemy.exc import IntegrityError
    from backend.database.models.group_student import GroupStudentModel

    student = db.query(StudentModel).filter(StudentModel.student_id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    # Remove from all groups first
    db.query(GroupStudentModel).filter(GroupStudentModel.student_id == student_id).delete(synchronize_session=False)

    try:
        db.delete(student)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Cannot delete this student because they are still referenced by other data."
        )
    return {"message": "Student cleanly deleted"}

def bulk_delete_students(db: Session, student_ids: list[str]):
    from backend.database.models.group_student import GroupStudentModel
    # Remove from groups first
    db.query(GroupStudentModel).filter(GroupStudentModel.student_id.in_(student_ids)).delete(synchronize_session=False)
    # Delete students
    count = db.query(StudentModel).filter(StudentModel.student_id.in_(student_ids)).delete(synchronize_session=False)
    db.commit()
    return count

def bulk_update_students(db: Session, student_ids: list[str], branch_id: int | None, batch: int | None, program: str | None):
    update_data = {}
    if branch_id is not None: update_data['branch_id'] = branch_id
    if batch is not None: update_data['batch'] = batch
    if program is not None: update_data['program'] = program
    
    if not update_data:
        return 0
        
    count = db.query(StudentModel).filter(StudentModel.student_id.in_(student_ids)).update(update_data, synchronize_session=False)
    db.commit()
    return count
