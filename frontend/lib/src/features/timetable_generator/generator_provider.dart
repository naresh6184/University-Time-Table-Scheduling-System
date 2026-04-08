import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/models/timetable_models.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';
import 'package:university_timetable_frontend/src/features/timetable_view/timetable_grid_provider.dart';
import 'dart:async';

// --- Versions Provider ---
final versionsProvider = AsyncNotifierProvider<VersionsNotifier, List<TimetableVersion>>(
  VersionsNotifier.new,
);

class VersionsNotifier extends AsyncNotifier<List<TimetableVersion>> {
  @override
  Future<List<TimetableVersion>> build() async {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return [];

    final api = ref.read(apiServiceProvider);
    final response = await api.get('/timetable/versions', queryParameters: {
      'session_id': session.sessionId,
    });
    
    final List<dynamic> data = response.data['versions'];
    return data.map((json) => TimetableVersion.fromJson(json)).toList();
  }

  Future<void> activateVersion(int versionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      await api.post('/timetable/version/$versionId/activate');
      
      // Invalidate grid data so it re-fetches for the new active version
      ref.invalidate(gridDataProvider);
      
      return build();
    });
  }

  Future<void> deleteVersion(int versionId) async {
    final api = ref.read(apiServiceProvider);
    await api.delete('/timetable/version/$versionId');
    // Refresh the list after deleting
    ref.invalidateSelf();
    await future;
    
    // If we deleted the actively viewed version, reset grid
    final gridVersion = ref.read(selectedVersionIdProvider);
    if (gridVersion == versionId) {
        ref.read(selectedVersionIdProvider.notifier).set(null);
        ref.invalidate(gridDataProvider);
    }
  }
}

// --- Generation Notifier ---
enum GenerationStatus { idle, generating, success, error }

class GenerationState {
  final GenerationStatus status;
  final GenerationResult? result;
  final String? errorMessage;
  final GenerationStatusData? statusData;

  GenerationState({required this.status, this.result, this.errorMessage, this.statusData});
}

final generationNotifierProvider = NotifierProvider<GenerationNotifier, GenerationState>(
  GenerationNotifier.new,
);

class GenerationNotifier extends Notifier<GenerationState> {
  Timer? _pollingTimer;

  @override
  GenerationState build() => GenerationState(status: GenerationStatus.idle);

  Future<void> generate({int? population, int? generations}) async {
    final session = ref.read(activeSessionProvider);
    if (session == null) {
      state = GenerationState(status: GenerationStatus.error, errorMessage: 'No session selected');
      return;
    }

    state = GenerationState(status: GenerationStatus.generating);
    _startPolling();
    
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/timetable/generate', 
        queryParameters: {
            'session_id': session.sessionId,
            if (population != null) 'population': population,
            if (generations != null) 'generations': generations,
        },
        options: Options(receiveTimeout: const Duration(minutes: 60)), // 60 minutes max for generation logic
      );
      
      final result = GenerationResult.fromJson(response.data);
      _stopPolling();
      await _fetchStatus(); // Final update
      
      state = GenerationState(status: GenerationStatus.success, result: result, statusData: state.statusData);
      
      // Refresh versions list and timetable grid after generation
      ref.invalidate(versionsProvider);
      ref.invalidate(gridDataProvider);
    } catch (e) {
      _stopPolling();
      state = GenerationState(status: GenerationStatus.error, errorMessage: e.toString());
    }
  }

  void _startPolling() {
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
          _fetchStatus();
      });
  }

  void _stopPolling() {
      _pollingTimer?.cancel();
      _pollingTimer = null;
  }

  Future<void> _fetchStatus() async {
      final session = ref.read(activeSessionProvider);
      if (session == null) return;
      try {
          final api = ref.read(apiServiceProvider);
          final response = await api.get('/timetable/generate/status', queryParameters: {'session_id': session.sessionId});
          if (response.data != null && response.data['status'] != 'Idle') {
              final statusData = GenerationStatusData.fromJson(response.data);
              // Update state while keeping the primary status intact
              if (state.status == GenerationStatus.generating || state.status == GenerationStatus.success) {
                  state = GenerationState(status: state.status, result: state.result, errorMessage: state.errorMessage, statusData: statusData);
              }
          }
      } catch (e) {
          // Ignore polling errors
      }
  }

  Future<void> cancel() async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;
    try {
        final api = ref.read(apiServiceProvider);
        await api.post('/timetable/cancel', queryParameters: {
            'session_id': session.sessionId,
        });
        // State will update when generate() unblocks or receives the cancelled response
    } catch (e) {
        // Ignore or handle cancel error
    }
  }

  void reset() {
    _stopPolling();
    state = GenerationState(status: GenerationStatus.idle);
  }
}
