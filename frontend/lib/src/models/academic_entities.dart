class TeacherModel {
  final int teacherId;
  final String name;
  final String code;
  final String? email;

  TeacherModel({
    required this.teacherId,
    required this.name,
    required this.code,
    this.email,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    return TeacherModel(
      teacherId: json['teacher_id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teacher_id': teacherId,
      'name': name,
      'code': code,
      'email': email,
    };
  }
}



class ClassroomModel {
  final int roomId;
  final String name;
  final int capacity;
  final String roomType;

  ClassroomModel({
    required this.roomId,
    required this.name,
    required this.capacity,
    required this.roomType,
  });

  factory ClassroomModel.fromJson(Map<String, dynamic> json) {
    return ClassroomModel(
      roomId: json['room_id'] as int,
      name: json['name'] as String,
      capacity: json['capacity'] as int,
      roomType: json['room_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'name': name,
      'capacity': capacity,
      'room_type': roomType,
    };
  }
}

class SubjectModel {
  final int subjectId;
  final String name;
  final String code;
  final String? abbreviation;
  final String subjectType;
  final int hoursPerWeek;

  SubjectModel({
    required this.subjectId,
    required this.name,
    required this.code,
    this.abbreviation,
    required this.subjectType,
    required this.hoursPerWeek,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      subjectId: json['subject_id'] as int,
      name: json['name'] as String,
      code: json['code'] as String? ?? '',
      abbreviation: json['abbreviation'] as String?,
      subjectType: json['subject_type'] as String,
      hoursPerWeek: json['hours_per_week'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'name': name,
      'code': code,
      'abbreviation': abbreviation,
      'subject_type': subjectType,
      'hours_per_week': hoursPerWeek,
    };
  }
}


