from sqladmin import Admin, ModelView
from backend.database.session import engine

from backend.database.models.branch import BranchModel
from backend.database.models.classroom import ClassroomModel
from backend.database.models.teacher import TeacherModel
from backend.database.models.subject import SubjectModel
from backend.database.models.student import StudentModel
from backend.database.models.group import GroupModel
from backend.database.models.enrollment import EnrollmentModel
from backend.database.models.slot import SlotModel


class BranchAdmin(ModelView, model=BranchModel):
    column_list = [BranchModel.branch_id, BranchModel.name]


class ClassroomAdmin(ModelView, model=ClassroomModel):
    column_list = ["room_id", "capacity", "room_type"]


class TeacherAdmin(ModelView, model=TeacherModel):
    column_list = ["teacher_id"]


class SubjectAdmin(ModelView, model=SubjectModel):
    column_list = ["subject_id", "name", "subject_type", "hours_per_week"]


class StudentAdmin(ModelView, model=StudentModel):
    column_list = ["student_id", "branch_id"]


class GroupAdmin(ModelView, model=GroupModel):
    column_list = ["group_id", "name"]


class EnrollmentAdmin(ModelView, model=EnrollmentModel):
    column_list = [
        "enrollment_id",
        "group_id",
        "subject_id",
        "teacher_id",
        "partition"
    ]


class SlotAdmin(ModelView, model=SlotModel):
    column_list = [
        "slot_id",
        "day",
        "period_number",
        "start_time",
        "end_time"
    ]