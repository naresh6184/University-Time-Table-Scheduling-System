import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/features/data_center/teacher_availability_provider.dart';
import 'package:university_timetable_frontend/src/features/slot_config/slot_config_provider.dart';
import 'package:university_timetable_frontend/src/features/enrollment/enrollment_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_entities_provider.dart';
import 'dart:async';

class SyncStatus {
  final bool outOfSync;
  final Map<String, bool> details;
  final String? lastSyncedAt;

  SyncStatus({
    required this.outOfSync,
    required this.details,
    this.lastSyncedAt,
  });

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      outOfSync: json['out_of_sync'],
      details: Map<String, bool>.from(json['details']),
      lastSyncedAt: json['last_synced_at'],
    );
  }
}

final sessionSyncProvider = AsyncNotifierProvider<SessionSyncNotifier, SyncStatus>(
  SessionSyncNotifier.new,
);

class SessionSyncNotifier extends AsyncNotifier<SyncStatus> {
  Timer? _pollTimer;

  @override
  Future<SyncStatus> build() async {
    final activeSession = ref.watch(activeSessionProvider);
    
    // Setup polling (15 seconds)
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
       _fetchLatestStatus();
    });
    
    ref.onDispose(() {
      _pollTimer?.cancel();
    });

    if (activeSession == null || activeSession.sessionId == -1) {
      return SyncStatus(outOfSync: false, details: {});
    }

    return _fetchLatestStatus(isInitial: true);
  }

  Future<SyncStatus> _fetchLatestStatus({bool isInitial = false}) async {
    final activeSession = ref.read(activeSessionProvider);
    if (activeSession == null || activeSession.sessionId == -1) {
      return SyncStatus(outOfSync: false, details: {});
    }

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/admin/sessions/${activeSession.sessionId}/sync-status');
      final newStatus = SyncStatus.fromJson(response.data);
      
      if (!isInitial) {
         state = AsyncData(newStatus);
      }
      return newStatus;
    } catch (e) {
      if (isInitial) rethrow;
      return state.value ?? SyncStatus(outOfSync: false, details: {});
    }
  }

  Future<void> triggerSync({bool ignoreAvailability = false}) async {
    final activeSession = ref.read(activeSessionProvider);
    if (activeSession == null || activeSession.sessionId == -1) return;

    final prevState = state;
    state = const AsyncLoading();
    
    try {
      final api = ref.read(apiServiceProvider);
      await api.post(
        '/admin/sessions/${activeSession.sessionId}/sync-trigger',
        queryParameters: {'ignore_availability': ignoreAvailability},
      );
      
      // Proactive refresh
      ref.invalidate(slotConfigProvider);
      ref.invalidate(teacherAvailabilityProvider);
      ref.invalidate(enrollmentsProvider);
      ref.invalidate(sessionTeachersProvider);
      ref.invalidate(sessionSubjectsProvider);
      ref.invalidate(sessionGroupsProvider);
      ref.invalidate(sessionRoomsProvider);

      await _fetchLatestStatus();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
