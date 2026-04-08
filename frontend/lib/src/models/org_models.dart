class BranchModel {
  final int branchId;
  final String name;
  final String? abbreviation;

  BranchModel({required this.branchId, required this.name, this.abbreviation});

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      branchId: json['branch_id'] as int,
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String?,
    );
  }
}


class GroupModel {
  final int groupId;
  final String name;
  final String? description;
  final int studentCount;
  final String? program;
  final int? batch;
  final int? branchId;

  GroupModel({
    required this.groupId, 
    required this.name, 
    this.description, 
    this.studentCount = 0,
    this.program,
    this.batch,
    this.branchId,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      groupId: json['group_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      studentCount: json['student_count'] as int? ?? 0,
      program: json['program'] as String?,
      batch: json['batch'] as int?,
      branchId: json['branch_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'name': name,
      'description': description,
      'program': program,
      'batch': batch,
      'branch_id': branchId,
    };
  }
}

class StudentModel {
  final String studentId;
  final String name;
  final int branchId;
  final int? batch;
  final String? email;
  final String program;

  StudentModel({
    required this.studentId,
    required this.name,
    required this.branchId,
    this.batch,
    this.email,
    this.program = 'B.Tech',
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      studentId: json['student_id'] as String,
      name: json['name'] as String,
      branchId: json['branch_id'] as int,
      batch: json['batch'] as int?,
      email: json['email'] as String?,
      program: json['program'] as String? ?? 'B.Tech',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'name': name,
      'branch_id': branchId,
      'batch': batch,
      'email': email,
      'program': program,
    };
  }
}

class EnrollmentModel {
  final int enrollmentId;
  final int teacherId;
  final int subjectId;
  final int groupId;
  final String? partition;

  EnrollmentModel({
    required this.enrollmentId,
    required this.teacherId,
    required this.subjectId,
    required this.groupId,
    this.partition,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentModel(
      enrollmentId: json['enrollment_id'] as int,
      teacherId: json['teacher_id'] as int,
      subjectId: json['subject_id'] as int,
      groupId: json['group_id'] as int,
      partition: json['partition'] as String?,
    );
  }
}
