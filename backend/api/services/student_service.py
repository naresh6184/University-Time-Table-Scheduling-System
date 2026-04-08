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
