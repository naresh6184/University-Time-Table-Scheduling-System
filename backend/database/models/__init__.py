from backend.database.session import Base, SessionLocal, engine
from backend.database.models.branch import BranchModel
from backend.database.models.student import StudentModel
from backend.database.models.group import GroupModel
from backend.database.models.group_student import GroupStudentModel
from backend.database.models.teacher import TeacherModel
from backend.database.models.teacher_availability import TeacherAvailabilityModel, SessionTeacherAvailabilityModel
from backend.database.models.classroom import ClassroomModel
from backend.database.models.subject import SubjectModel
from backend.database.models.enrollment import EnrollmentModel
from backend.database.models.slot import SlotModel
from backend.database.models.timetable_version import TimetableVersionModel
from backend.database.models.timetable_entry import TimetableEntryModel
from backend.database.models.session import SessionModel
from backend.database.models.session_entities import (
    SessionTeacherModel,
    SessionSubjectModel,
    SessionGroupModel,
    SessionClassroomModel,
)
from backend.database.models.timetable_conflict_type import TimetableConflictTypeModel
from backend.database.models.timetable_conflict import TimetableConflictModel