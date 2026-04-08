import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';

class TeacherAvailabilityConfig {
  final int teacherId;
  final List<Map<String, dynamic>> entries;

  TeacherAvailabilityConfig({
    required this.teacherId,
    required this.entries,
  });

  factory TeacherAvailabilityConfig.fromJson(int teacherId, Map<String, dynamic> json) {
    return TeacherAvailabilityConfig(
      teacherId: teacherId,
      entries: List<Map<String, dynamic>>.from(json['entries'] ?? []),
    );
  }
}

class TeacherAvailabilityParams {
  final int teacherId;
  final int sessionId;

  TeacherAvailabilityParams(this.teacherId, this.sessionId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherAvailabilityParams &&
          runtimeType == other.runtimeType &&
          teacherId == other.teacherId &&
          sessionId == other.sessionId;

  @override
  int get hashCode => teacherId.hashCode ^ sessionId.hashCode;
}

final teacherAvailabilityProvider = FutureProvider.family<TeacherAvailabilityConfig, TeacherAvailabilityParams>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get(
    '/admin/teacher-availability/${params.teacherId}',
    queryParameters: {'session_id': params.sessionId},
  );
  return TeacherAvailabilityConfig.fromJson(params.teacherId, response.data);
});

final saveAvailabilityProvider = Provider((ref) => SaveAvailabilityService(ref));

class SaveAvailabilityService {
  final Ref ref;
  SaveAvailabilityService(this.ref);

  Future<void> save(int teacherId, List<Map<String, dynamic>> entries, {int sessionId = -1, List<Map<String, dynamic>>? allSlots}) async {
    final api = ref.read(apiServiceProvider);
    await api.post(
      '/admin/teacher-availability/$teacherId/bulk', 
      queryParameters: {'session_id': sessionId},
      data: {
        'entries': entries,
        if (allSlots != null) 'all_slots': allSlots,
      },
    );
    // Invalidate the provider with the same params to trigger a refresh
    ref.invalidate(teacherAvailabilityProvider(TeacherAvailabilityParams(teacherId, sessionId)));
  }
}
