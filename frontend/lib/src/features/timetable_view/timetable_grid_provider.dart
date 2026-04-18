import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/models/grid_models.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';

enum TimetableEntityType { group, teacher, room }

class TimetableEntity {
  final TimetableEntityType type;
  final int id;
  final String name;

  TimetableEntity({required this.type, required this.id, required this.name});
}

// Optional version ID for viewing historical versions
final selectedVersionIdProvider = NotifierProvider<SelectedVersionIdNotifier, int?>(
  SelectedVersionIdNotifier.new,
);

class SelectedVersionIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? val) => state = val;
}

final selectedTableEntityProvider = NotifierProvider<SelectedTableEntityNotifier, TimetableEntity?>(
  SelectedTableEntityNotifier.new,
);

class SelectedTableEntityNotifier extends Notifier<TimetableEntity?> {
  @override
  TimetableEntity? build() => null;

  void set(TimetableEntity? entity) => state = entity;
}

final gridDataProvider = AsyncNotifierProvider<GridDataNotifier, GridResponse?>(
  GridDataNotifier.new,
);

class GridDataNotifier extends AsyncNotifier<GridResponse?> {
  @override
  Future<GridResponse?> build() async {
    final entity = ref.watch(selectedTableEntityProvider);
    final versionId = ref.watch(selectedVersionIdProvider);
    
    if (entity == null) return null;

    final api = ref.read(apiServiceProvider);
    final endpoint = '/timetable/${entity.type.name}/${entity.id}/grid';
    
    final queryParams = versionId != null ? {'version_id': versionId} : null;
    final response = await api.get(endpoint, queryParameters: queryParams);
    return GridResponse.fromJson(response.data);
  }

  void refresh() => ref.invalidateSelf();
}

class ActiveEntities {
  final List<int> groups;
  final List<int> teachers;
  final List<int> rooms;
  final List<int> branches;

  ActiveEntities({
    required this.groups,
    required this.teachers,
    required this.rooms,
    required this.branches,
  });

  factory ActiveEntities.fromJson(Map<String, dynamic> json) {
    return ActiveEntities(
      groups: List<int>.from(json['groups'] ?? []),
      teachers: List<int>.from(json['teachers'] ?? []),
      rooms: List<int>.from(json['rooms'] ?? []),
      branches: List<int>.from(json['branches'] ?? []),
    );
  }
}

final activeTimetableEntitiesProvider = FutureProvider<ActiveEntities>((ref) async {
  final api = ref.read(apiServiceProvider);
  final versionId = ref.watch(selectedVersionIdProvider);
  final activeSession = ref.watch(activeSessionProvider);
  
  if (activeSession == null || activeSession.sessionId == -1) {
    return ActiveEntities(groups: [], teachers: [], rooms: [], branches: []);
  }

  try {
    final queryParams = <String, dynamic>{'session_id': activeSession.sessionId};
    if (versionId != null) queryParams['version_id'] = versionId;
    
    final response = await api.get('/timetable/active-entities', queryParameters: queryParams);
    return ActiveEntities.fromJson(response.data);
  } catch (e) {
    return ActiveEntities(groups: [], teachers: [], rooms: [], branches: []);
  }
});

// ---- Conflict data models and providers ----

// A single conflict item on a slot (type + detail text for tooltip + entity info for filtering)
class SlotConflict {
  final String type;
  final String detail;
  final String? room;
  final String? teacher;
  final String? group;
  final List<int> enrollmentIds;
  final List<int> entryIds;

  SlotConflict({required this.type, required this.detail, this.room, this.teacher, this.group, this.enrollmentIds = const [], this.entryIds = const []});

  factory SlotConflict.fromJson(Map<String, dynamic> json) {
    return SlotConflict(
      type: json['type'] as String,
      detail: json['detail'] as String,
      room: json['room'] as String?,
      teacher: json['teacher'] as String?,
      group: json['group'] as String?,
      enrollmentIds: (json['enrollment_ids'] as List?)?.map((e) => e as int).toList() ?? const [],
      entryIds: (json['entry_ids'] as List?)?.map((e) => e as int).toList() ?? const [],
    );
  }

  /// Check if this conflict is relevant to a given cell.
  /// Uses entry_ids as the most precise filter when available.
  bool isRelevantTo({String? cellRoom, String? cellTeacher, String? cellGroup, int? cellEntryId, int? cellEnrollmentId}) {
    // Primary precision filter: if we have entry_ids, the cell must match one
    if (entryIds.isNotEmpty && cellEntryId != null) {
      return entryIds.contains(cellEntryId);
    }
    // Secondary: check enrollment_ids
    if (enrollmentIds.isNotEmpty && cellEnrollmentId != null) {
      return enrollmentIds.contains(cellEnrollmentId);
    }
    // Fallback to type-aware entity field matching
    if (type == 'Capacity' || type == 'Type Mismatch') {
      return (room != null && cellRoom == room) && (group != null && cellGroup == group);
    } else if (type == 'Teacher Overlap' || type == 'Availability') {
      return teacher != null && cellTeacher == teacher;
    } else if (type == 'Room Overlap') {
      return room != null && cellRoom == room;
    } else if (type == 'Group Double-Book' || type == 'Student Overlap') {
      return group != null && cellGroup == group;
    }

    // Generic fallback
    if (room != null && cellRoom != null && room == cellRoom) return true;
    if (teacher != null && cellTeacher != null && teacher == cellTeacher) return true;
    if (group != null && cellGroup != null && group == cellGroup) return true;
    if (room == null && teacher == null && group == null) return true;
    return false;
  }
}

class ConflictSummaryItem {
  final String type;
  final int count;

  ConflictSummaryItem({required this.type, required this.count});

  factory ConflictSummaryItem.fromJson(Map<String, dynamic> json) {
    return ConflictSummaryItem(
      type: json['type'] as String,
      count: json['count'] as int,
    );
  }
}

class VersionConflictsData {
  final int total;
  final List<ConflictSummaryItem> summary;
  // Key: "Day_Period" (e.g. "Monday_1"), Value: list of conflicts at that slot
  final Map<String, List<SlotConflict>> bySlot;

  VersionConflictsData({required this.total, required this.summary, required this.bySlot});

  factory VersionConflictsData.fromJson(Map<String, dynamic> json) {
    final bySlotRaw = json['by_slot'] as Map<String, dynamic>? ?? {};
    final bySlot = bySlotRaw.map((key, value) => MapEntry(
      key,
      (value as List).map((e) => SlotConflict.fromJson(e as Map<String, dynamic>)).toList(),
    ));

    return VersionConflictsData(
      total: json['total'] as int,
      summary: (json['summary'] as List?)?.map((e) => ConflictSummaryItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      bySlot: bySlot,
    );
  }

  /// Check if a given day+period has any conflicts (optionally filtered by type)
  List<SlotConflict> getConflictsAt(String day, int period, {String? filterType}) {
    final key = '${day}_$period';
    final list = bySlot[key] ?? [];
    if (filterType != null) {
      return list.where((c) => c.type == filterType).toList();
    }
    return list;
  }

  /// Get all slot keys that should be highlighted when a conflict cell is clicked.
  /// Uses semantics to highlight all connected cells (e.g. all classes of G1 in AB101).
  Set<int> getRelatedConflictSlots(
    List<SlotConflict> conflictsAtSlotRaw,
    String sourceSlotKey,
    GridResponse? grid,
    {String? typeFilter}
  ) {
    final related = <int>{};
    if (conflictsAtSlotRaw.isEmpty || grid == null) return related;

    final conflictsAtSlot = typeFilter == null
        ? conflictsAtSlotRaw
        : conflictsAtSlotRaw.where((c) => c.type == typeFilter).toList();

    for (final dayEntry in grid.grid.entries) {
      for (final cell in dayEntry.value) {
        if (cell.isEmpty) continue;

        // Helper to check a single grid cell (primary or stacked)
        void checkCell(GridCell c) {
          if (c.entryId == null) return;
          bool matches = false;
          for (final conflict in conflictsAtSlot) {
            if (conflict.type == 'Capacity') {
              // Persistent constraints: highlight all occurrences across the week that share this exact combo
              if (conflict.room != null && conflict.group != null && c.room == conflict.room && c.group == conflict.group) {
                matches = true; break;
              }
            } else if (conflict.type == 'Type Mismatch') {
               // Type mismatch applies to the entire enrollment requirement (all classes for this subject)
               if (c.enrollmentId != null && conflict.enrollmentIds.contains(c.enrollmentId)) {
                 matches = true; break;
               }
            } else {
              // Slot-specific constraints (Availability, Overlaps, etc.): ONLY highlight the exact involved entries
              if (conflict.entryIds.contains(c.entryId)) {
                matches = true; break;
              }
            }
          }
          if (matches) {
            related.add(c.entryId!);
          }
        }

        checkCell(cell);
        for (final stacked in cell.stackedEntries) {
          checkCell(stacked);
        }
      }
    }
    return related;
  }


  // Helper to remove period-specific notes so we can match the same "incident" across multiple slots
  String _normalizeConflictDetail(String detail) {
    return detail
        .replaceAll(RegExp(r', \d+h class starting P\d+'), '')
        .replaceAll(RegExp(r', starting P\d+'), '');
  }
}

// Provider: fetches detailed conflicts for the currently selected version
final versionConflictsProvider = FutureProvider<VersionConflictsData?>((ref) async {
  final versionId = ref.watch(selectedVersionIdProvider);
  if (versionId == null) return null;

  final api = ref.read(apiServiceProvider);
  try {
    final response = await api.get('/timetable/version/$versionId/conflicts');
    return VersionConflictsData.fromJson(response.data);
  } catch (e) {
    return null;
  }
});


// Provider: tracks which conflict type the user has selected for highlighting
final activeConflictFilterProvider = NotifierProvider<ActiveConflictFilterNotifier, String?>(
  ActiveConflictFilterNotifier.new,
);

class ActiveConflictFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}


// Provider: tracks which session entry IDs should be highlighted
final highlightedEntryIdsProvider = NotifierProvider<HighlightedEntryIdsNotifier, Set<int>>(
  HighlightedEntryIdsNotifier.new,
);

class HighlightedEntryIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => {};

  void highlight(Set<int> entryIds) => state = entryIds;
  void clear() => state = {};
  void toggle(int clickedEntryId, Set<int> relatedEntryIds) {
    if (state.contains(clickedEntryId) || state.containsAll(relatedEntryIds)) {
      state = {};
    } else {
      state = {clickedEntryId, ...relatedEntryIds};
    }
  }
}


// ---- Conflict Type Descriptions ----
const Map<String, String> conflictTypeDescriptions = {
  'Teacher Overlap': 'A teacher is scheduled to teach two or more classes at the exact same time. They can only be in one place.',
  'Room Overlap': 'Two or more classes are assigned to the same room at the same time slot. A room can only hold one class.',
  'Group Double-Book': 'A student group has two classes scheduled at the same time. Students in this group cannot attend both.',
  'Student Overlap': 'Students belonging to multiple groups are double-booked — their groups have classes at the same time.',
  'Availability': 'A teacher is scheduled during a time slot they marked as unavailable (e.g., personal commitment).',
  'Capacity': 'The assigned room does not have enough seats for all the students in the group.',
  'Type Mismatch': 'The room type (e.g., lab) does not match the subject type (e.g., theory lecture).',
  'Same-Day Duplicate': 'The same class is scheduled more than once on the same day.',
  'Lunch Break Conflict': 'A multi-hour class spans across the lunch break period.',
  'Crosses Day Boundary': 'A multi-hour class extends beyond the last period of the day.',
};
