import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';

class SqlResponse {
  final bool success;
  final bool isSelect;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final int rowsAffected;
  final String message;

  SqlResponse({
    required this.success,
    required this.isSelect,
    required this.columns,
    required this.rows,
    required this.rowsAffected,
    required this.message,
  });

  factory SqlResponse.fromJson(Map<String, dynamic> json) {
    return SqlResponse(
      success: json['success'] ?? false,
      isSelect: json['is_select'] ?? false,
      columns: List<String>.from(json['columns'] ?? []),
      rows: List<Map<String, dynamic>>.from(json['rows'] ?? []),
      rowsAffected: json['rows_affected'] ?? 0,
      message: json['message'] ?? '',
    );
  }
}

final sqlControllerProvider = Provider((ref) => SqlController(ref));

class SqlController {
  final Ref ref;

  SqlController(this.ref);

  Future<SqlResponse> executeQuery(String query, String password) async {
    final api = ref.read(apiServiceProvider);
    
    // We do NOT use AsyncValue.guard here because we want the UI
    // to catch the DioException directly to show the specific error message
    // returned by our backend backend/api/routers/admin/sql_router.py
    final response = await api.post(
      '/admin/sql/execute',
      data: {
        'query': query,
        'password': password
      },
    );
    
    return SqlResponse.fromJson(response.data);
  }

  Future<bool> verifyPassword(String password) async {
    final api = ref.read(apiServiceProvider);
    try {
      final response = await api.post('/admin/sql/verify', data: {'password': password});
      return response.data['success'] == true;
    } catch (e) {
      return false; // Any error means unauthorized
    }
  }
}

class DevAuthState {
  final bool isUnlocked;
  final DateTime? lastActivity;
  final String? cachedPassword;
  final int? secondsUntilLock;

  DevAuthState({
    this.isUnlocked = false,
    this.lastActivity,
    this.cachedPassword,
    this.secondsUntilLock,
  });

  DevAuthState copyWith({
    bool? isUnlocked,
    DateTime? lastActivity,
    String? cachedPassword,
    int? secondsUntilLock,
  }) {
    return DevAuthState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      lastActivity: lastActivity ?? this.lastActivity,
      cachedPassword: cachedPassword ?? this.cachedPassword,
      secondsUntilLock: secondsUntilLock, // intentionally not using ?? to allow setting to null
    );
  }
}

class DevAuthNotifier extends Notifier<DevAuthState> {
  Timer? _timer;

  @override
  DevAuthState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return DevAuthState();
  }

  void unlock(String password) {
    state = state.copyWith(
      isUnlocked: true,
      lastActivity: DateTime.now(),
      cachedPassword: password,
      secondsUntilLock: null, // Clear any previous countdown
    );
    _startTimer();
  }

  void lock() {
    _timer?.cancel();
    state = DevAuthState(); // Reset to default (locked, no password)
  }

  void registerActivity() {
    if (!state.isUnlocked) return;
    state = state.copyWith(
      lastActivity: DateTime.now(),
      secondsUntilLock: null, // clear countdown
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isUnlocked || state.lastActivity == null) return;

      final diff = DateTime.now().difference(state.lastActivity!).inSeconds;
      
      // Auto-lock after 300 seconds (5 minutes)
      if (diff >= 300) {
        lock();
      } 
      // Show countdown for the last 45 seconds
      else if (diff >= 255) {
        state = state.copyWith(secondsUntilLock: 300 - diff);
      } 
      // Ensure countdown is hidden if under 255
      else if (state.secondsUntilLock != null) {
        state = state.copyWith(secondsUntilLock: null);
      }
    });
  }
}

final devAuthNotifierProvider = NotifierProvider<DevAuthNotifier, DevAuthState>(() {
  return DevAuthNotifier();
});
