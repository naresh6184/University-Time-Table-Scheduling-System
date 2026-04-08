import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- Teachers Provider ---
import 'package:university_timetable_frontend/src/models/academic_entities.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';

// --- Teachers Provider ---
final teachersProvider = AsyncNotifierProvider<TeachersNotifier, List<TeacherModel>>(
  TeachersNotifier.new,
);

class TeachersNotifier extends AsyncNotifier<List<TeacherModel>> {
  @override
  Future<List<TeacherModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/admin/teachers/');
    final List<dynamic> data = response.data;
    return data.map((json) => TeacherModel.fromJson(json)).toList();
  }

  Future<int> addTeacher(String name, String code, String? email) async {
    final api = ref.read(apiServiceProvider);
    final response = await api.post('/admin/teachers/', data: {
      'name': name,
      'code': code,
      'email': email,
    });
    ref.invalidateSelf();
    return response.data['teacher_id'];
  }

  Future<void> updateTeacher(int id, String name, String code, String? email) async {
    final api = ref.read(apiServiceProvider);
    await api.put('/admin/teachers/$id', data: {
      'name': name,
      'code': code,
      'email': email,
    });
    ref.invalidateSelf();
  }


  Future<void> deleteTeacher(int id) async {
    final api = ref.read(apiServiceProvider);
    await api.delete('/admin/teachers/$id');
    ref.invalidateSelf();
  }
}

// --- Classrooms Provider ---
final classroomsProvider = AsyncNotifierProvider<ClassroomsNotifier, List<ClassroomModel>>(
  ClassroomsNotifier.new,
);

class ClassroomsNotifier extends AsyncNotifier<List<ClassroomModel>> {
  @override
  Future<List<ClassroomModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/admin/classrooms/');
    final List<dynamic> data = response.data;
    return data.map((json) => ClassroomModel.fromJson(json)).toList();
  }

  Future<int> addClassroom(String name, int capacity, String type) async {
    final api = ref.read(apiServiceProvider);
    final response = await api.post('/admin/classrooms/', data: {
      'name': name,
      'capacity': capacity,
      'room_type': type,
    });
    ref.invalidateSelf();
    return response.data['room_id'];
  }

  Future<void> updateClassroom(int id, String name, int capacity, String type) async {
    final api = ref.read(apiServiceProvider);
    await api.put('/admin/classrooms/$id', data: {
      'name': name,
      'capacity': capacity,
      'room_type': type,
    });
    ref.invalidateSelf();
  }

  Future<void> deleteClassroom(int id) async {
    final api = ref.read(apiServiceProvider);
    await api.delete('/admin/classrooms/$id');
    ref.invalidateSelf();
  }
}

// --- Subjects Provider ---
final subjectsProvider = AsyncNotifierProvider<SubjectsNotifier, List<SubjectModel>>(
  SubjectsNotifier.new,
);

class SubjectsNotifier extends AsyncNotifier<List<SubjectModel>> {
  @override
  Future<List<SubjectModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/admin/subjects/');
    final List<dynamic> data = response.data;
    return data.map((json) => SubjectModel.fromJson(json)).toList();
  }

  Future<int> addSubject(String name, String code, String? abbreviation, String type, int hours) async {
    final api = ref.read(apiServiceProvider);
    final response = await api.post('/admin/subjects/', data: {
      'name': name,
      'code': code,
      'abbreviation': abbreviation,
      'subject_type': type,
      'hours_per_week': hours,
    });
    ref.invalidateSelf();
    return response.data['subject_id'];
  }

  Future<void> updateSubject(int id, String name, String code, String? abbreviation, String type, int hours) async {
    final api = ref.read(apiServiceProvider);
    await api.put('/admin/subjects/$id', data: {
      'name': name,
      'code': code,
      'abbreviation': abbreviation,
      'subject_type': type,
      'hours_per_week': hours,
    });
    ref.invalidateSelf();
  }


  Future<void> deleteSubject(int id) async {
    final api = ref.read(apiServiceProvider);
    await api.delete('/admin/subjects/$id');
    ref.invalidateSelf();
  }
}
