class PeriodMeta {
  final int period;
  final String start;
  final String end;

  PeriodMeta({required this.period, required this.start, required this.end});

  factory PeriodMeta.fromJson(Map<String, dynamic> json) {
    return PeriodMeta(
      period: json['period'] as int,
      start: json['start'] as String,
      end: json['end'] as String,
    );
  }
}

class GridCell {
  final String? subject;
  final String? group;
  final String? teacher;
  final String? room;
  final int? enrollmentId;
  final int? entryId;
  final int duration;
  final bool isContinuation;
  final List<GridCell> stackedEntries;

  GridCell({
    this.subject,
    this.group,
    this.teacher,
    this.room,
    this.enrollmentId,
    this.entryId,
    this.duration = 1,
    this.isContinuation = false,
    this.stackedEntries = const [],
  });

  factory GridCell.fromJson(Map<String, dynamic>? json) {
    if (json == null) return GridCell();
    return GridCell(
      subject: json['subject'] as String?,
      group: json['group'] as String?,
      teacher: json['teacher'] as String?,
      room: json['room'] as String?,
      enrollmentId: json['enrollmentId'] as int?,
      entryId: json['entryId'] as int?,
      duration: json['duration'] as int? ?? 1,
      isContinuation: json['isContinuation'] as bool? ?? false,
      stackedEntries: (json['stackedEntries'] as List?)
              ?.map((e) => GridCell.fromJson(e as Map<String, dynamic>?))
              .toList() ??
          const [],
    );
  }

  bool get isEmpty => subject == null;
  bool get hasStack => stackedEntries.isNotEmpty;
}

class GridResponse {
  final List<PeriodMeta> periods;
  final Map<String, List<GridCell>> grid;

  GridResponse({required this.periods, required this.grid});

  factory GridResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawGrid = json['grid'] as Map<String, dynamic>;
    final grid = <String, List<GridCell>>{};

    rawGrid.forEach((day, cells) {
      grid[day] = (cells as List).map((c) => GridCell.fromJson(c as Map<String, dynamic>?)).toList();
    });

    return GridResponse(
      periods: (json['periods'] as List).map((p) => PeriodMeta.fromJson(p)).toList(),
      grid: grid,
    );
  }
}
