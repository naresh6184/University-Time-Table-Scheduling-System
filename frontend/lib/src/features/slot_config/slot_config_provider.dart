import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';

import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';

class SlotConfig {
  final int startHour;
  final int endHour;
  final List<String> workingDays;
  final List<Map<String, dynamic>> slots;

  SlotConfig({
    required this.startHour,
    required this.endHour,
    required this.workingDays,
    required this.slots,
  });

  factory SlotConfig.fromJson(Map<String, dynamic> json) {
    return SlotConfig(
      startHour: json['start_hour'],
      endHour: json['end_hour'],
      workingDays: List<String>.from(json['working_days']),
      slots: List<Map<String, dynamic>>.from(json['slots']),
    );
  }
}

final slotConfigProvider = AsyncNotifierProvider<SlotConfigNotifier, SlotConfig>(
  SlotConfigNotifier.new,
);

class SlotConfigNotifier extends AsyncNotifier<SlotConfig> {
  @override
  Future<SlotConfig> build() async {
    final api = ref.read(apiServiceProvider);
    final activeSession = ref.watch(activeSessionProvider);
    final sessionId = activeSession?.sessionId ?? -1;
    
    final response = await api.get('/admin/slots/config', queryParameters: {'session_id': sessionId});
    return SlotConfig.fromJson(response.data);
  }

  Future<Map<String, dynamic>?> configureSlots(Map<String, dynamic> config) async {
    state = const AsyncLoading();
    Map<String, dynamic>? result;
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final activeSession = ref.read(activeSessionProvider);
      final sessionId = activeSession?.sessionId ?? -1;

      final response = await api.post('/admin/slots/configure', queryParameters: {'session_id': sessionId}, data: config);
      result = response.data;
      return build();
    });
    return result;
  }
}

