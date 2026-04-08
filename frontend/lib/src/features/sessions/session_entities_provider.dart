import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/models/academic_entities.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';

// --- Session Teachers ---
final sessionTeachersProvider = AsyncNotifierProvider<SessionTeachersNotifier, List<TeacherModel>>(
  SessionTeachersNotifier.new,
);

class SessionTeachersNotifier extends AsyncNotifier<List<TeacherModel>> {
  @override
  Future<List<TeacherModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final session = ref.watch(activeSessionProvider);
    if (session == null || session.sessionId == -1) return [];
    
    final response = await api.get('/admin/sessions/${session.sessionId}/teachers');
    final List<dynamic> data = response.data;
    return data.map((json) => TeacherModel.fromJson(json)).toList();
  }

  Future<void> addTeacherToSession(int teacherId) async {
    final api = ref.read(apiServiceProvider);
    final session = ref.read(activeSessionProvider);
    if (session == null || session.sessionId == -1) return;
    
    await api.post('/admin/sessions/${session.sessionId}/teachers/$teacherId');
    ref.invalidateSelf();
  }

  Future<void> removeTeacherFromSession(int teacherId) async {
    final api = ref.read(apiServiceProvider);
    final session = ref.read(activeSessionProvider);
    if (session == null || session.sessionId == -1) return;
    
    await api.delete('/admin/sessions/${session.sessionId}/teachers/$teacherId');
    ref.invalidateSelf();
  }
}

// --- Session Subjects ---
final sessionSubjectsProvider = AsyncNotifierProvider<SessionSubjectsNotifier, List<SubjectModel>>(
  SessionSubjectsNotifier.new,
);

class SessionSubjectsNotifier extends AsyncNotifier<List<SubjectModel>> {
  @override
  Future<List<SubjectModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final session = ref.watch(activeSessionProvider);
    if (session == null || session.sessionId == -1) return [];
    
    final response = await api.get('/admin/sessions/${session.sessionId}/subjects');
    final List<dynamic> data = response.data;
    return data.map((json) => SubjectModel.fromJson(json)).toList();
  }

  Future<void> addSubjectToSession(int subjectId) async {
    final api = ref.read(apiServiceProvider);
    final session = ref.read(activeSessionProvider);
    if (session == null || session.sessionId == -1) return;
    
    await api.post('/admin/sessions/${session.sessionId}/subjects/$subjectId');
    ref.invalidateSelf();
  }

  Future<void> removeSubjectFromSession(int subjectId) async {
    final api = ref.read(apiServiceProvider);
    final session = ref.read(activeSessionProvider);
    if (session == null || session.sessionId == -1) return;
    
    await api.delete('/admin/sessions/${session.sessionId}/subjects/$subjectId');
    ref.invalidateSelf();
  }
}

// --- Session Groups ---
final sessionGroupsProvider = AsyncNotifierProvider<SessionGroupsNotifier, List<GroupModel>>(
  SessionGroupsNotifier.new,
);

class SessionGroupsNotifier extends AsyncNotifier<List<GroupModel>> {
  @override
  Future<List<GroupModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final session = ref.watch(activeSessionProvider);
    if (session == null || session.sessionId == -1) return [];
    
    final response = await api.get('/admin/sessions/${session.sessionId}/groups');
    final List<dynamic> data = response.data;
    return data.map((json) => GroupModel.fromJson(json)).toList();
  }

  Future<void> addGroupToSession(int groupId) async {
    final api = ref.read(apiServiceProvider);
    final session = ref.read(activeSessionProvider);
    if (session == null || session.sessionId == -1) return;
    
    await api.post('/admin/sessions/${session.sessionId}/groups/$groupId');
    ref.invalidateSelf();
  }

  Future<void> removeGroupFromSession(int groupId) async {
    final api = ref.read(apiServiceProvider);
    final session = ref.read(activeSessionProvider);
    if (session == null || session.sessionId == -1) return;
    
    await api.delete('/admin/sessions/${session.sessionId}/groups/$groupId');
    ref.invalidateSelf();
  }
}

// --- Session Rooms ---
final sessionRoomsProvider = AsyncNotifierProvider<SessionRoomsNotifier, List<ClassroomModel>>(
  SessionRoomsNotifier.new,
);

class SessionRoomsNotifier extends AsyncNotifier<List<ClassroomModel>> {
  @override
  Future<List<ClassroomModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final session = ref.watch(activeSessionProvider);
    if (session == null || session.sessionId == -1) return [];
    
    final response = await api.get('/admin/sessions/${session.sessionId}/rooms');
    final List<dynamic> data = response.data;
    return data.map((json) => ClassroomModel.fromJson(json)).toList();
  }

  Future<void> addRoomToSession(int roomId) async {
    final api = ref.read(apiServiceProvider);
    final session = ref.read(activeSessionProvider);
    if (session == null || session.sessionId == -1) return;
    
    await api.post('/admin/sessions/${session.sessionId}/rooms/$roomId');
    ref.invalidateSelf();
  }

  Future<void> removeRoomFromSession(int roomId) async {
    final api = ref.read(apiServiceProvider);
    final session = ref.read(activeSessionProvider);
    if (session == null || session.sessionId == -1) return;
    
    await api.delete('/admin/sessions/${session.sessionId}/rooms/$roomId');
    ref.invalidateSelf();
  }
}
