import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable_frontend/src/models/session.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';

final sessionsProvider = AsyncNotifierProvider<SessionsNotifier, List<SessionModel>>(
  SessionsNotifier.new,
);

class SessionsNotifier extends AsyncNotifier<List<SessionModel>> {
  @override
  Future<List<SessionModel>> build() async {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/admin/sessions/');
    final List<dynamic> data = response.data;
    final sessions = data.map((json) => SessionModel.fromJson(json)).toList();
    
    // Auto-selection removed as per user request to not have a default workspace.

    return sessions;
  }

  Future<void> createSession(String name, {int? fromSessionId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      
      // 1. Create the session
      final response = await api.post('/admin/sessions/', data: {'name': name, 'is_active': true});
      final newSession = SessionModel.fromJson(response.data);
      
      // 2. If requested, import data from another session
      if (fromSessionId != null) {
        await api.post('/admin/sessions/${newSession.sessionId}/import-data', queryParameters: {
          'from_session_id': fromSessionId,
        });
      }
      
      // 3. FORCE refresh the provider and wait for it to complete
      ref.invalidateSelf();
      final updatedList = await ref.read(sessionsProvider.future);
      
      // 4. Auto-select the newly created session (triggers navigation)
      await ref.read(activeSessionProvider.notifier).setSession(newSession);
      
      return updatedList;
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }


  Future<void> deleteSession(int sessionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.delete('/admin/sessions/$sessionId');
      
      // If we just deleted the active session, clear it from the state
      final activeConfig = ref.read(activeSessionProvider);
      if (activeConfig?.sessionId == sessionId) {
        await ref.read(activeSessionProvider.notifier).clearSession();
      }
      
      return build();
    });
  }

  Future<void> updateSession(int sessionId, String newName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      
      final response = await api.put('/admin/sessions/$sessionId', data: {'name': newName});
      final updatedSession = SessionModel.fromJson(response.data);
      
      // If we just renamed the active session, update its name in state
      final activeConfig = ref.read(activeSessionProvider);
      if (activeConfig?.sessionId == sessionId) {
        await ref.read(activeSessionProvider.notifier).setSession(updatedSession);
      }
      
      return build();
    });
  }
}

final activeSessionProvider = NotifierProvider<ActiveSessionNotifier, SessionModel?>(
  ActiveSessionNotifier.new,
);

class ActiveSessionNotifier extends Notifier<SessionModel?> {
  static const _prefKey = 'active_session';

  @override
  SessionModel? build() {
    return null;
  }

  Future<void> setSession(SessionModel session) async {
    state = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(session.toJson()));
  }

  Future<void> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final session = SessionModel.fromJson(jsonDecode(saved));
      // Reject Central Database (-1) as a saved workspace
      if (session.sessionId != -1) {
        state = session;
      } else {
        await prefs.remove(_prefKey);
      }
    }
  }

  Future<void> clearSession() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
