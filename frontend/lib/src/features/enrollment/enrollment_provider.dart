import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';

// --- Enrollments Provider ---
final enrollmentsProvider = AsyncNotifierProvider<EnrollmentsNotifier, List<EnrollmentModel>>(
  EnrollmentsNotifier.new,
);

class EnrollmentsNotifier extends AsyncNotifier<List<EnrollmentModel>> {
  @override
  Future<List<EnrollmentModel>> build() async {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return [];
    
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/admin/enrollments/', queryParameters: {
      'session_id': session.sessionId,
    });
    final List<dynamic> data = response.data;
    return data.map((json) => EnrollmentModel.fromJson(json)).toList();
  }

  Future<void> addEnrollment({
    required int teacherId,
    required int subjectId,
    required int groupId,
    String? partition,
  }) async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.post('/admin/enrollments/', data: {
        'session_id': session.sessionId,
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'group_id': groupId,
        'partition': partition,
      });
      return build();
    });
  }

  Future<void> updateEnrollment(int id, {
    int? teacherId,
    int? subjectId,
    int? groupId,
    String? partition,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.put('/admin/enrollments/$id', data: {
        if (teacherId != null) 'teacher_id': teacherId,
        if (subjectId != null) 'subject_id': subjectId,
        if (groupId != null) 'group_id': groupId,
        'partition': partition,
      });
      return build();
    });
  }

  Future<void> deleteEnrollment(int id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.delete('/admin/enrollments/$id');
      return build();
    });
  }
}
