from dataclasses import dataclass
from typing import Set, Dict, List


# ------------------ BASIC ENTITIES ------------------

@dataclass
class Branch:
    branch_id: int
    name: str
    students: Set[str]


@dataclass
class Student:
    student_id: str
    branch_id: int


@dataclass
class Group:
    group_id: int
    name: str
    students: Set[str]


@dataclass
class Teacher:
    teacher_id: int
    available_slots: Set[int]
    slot_preferences: Dict[int, int]


@dataclass
class Classroom:
    room_id: int
    capacity: int
    room_type: str


@dataclass
class Subject:
    subject_id: int
    name: str
    subject_type: str
    hours_per_week: int


@dataclass
class Enrollment:
    enrollment_id: int
    group_id: int
    subject_id: int
    teacher_id: int
    partition: List[int]
    duration: int = 1