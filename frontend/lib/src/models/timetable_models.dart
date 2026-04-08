class TimetableVersion {
  final int sessionId;
  final int versionId;
  final int populationSize;
  final int generations;
  final int bestViolation;
  final double bestSoftScore;
  final bool isActive;
  final int? isDuplicateOf;

  TimetableVersion({
    required this.sessionId,
    required this.versionId,
    required this.populationSize,
    required this.generations,
    required this.bestViolation,
    required this.bestSoftScore,
    required this.isActive,
    this.isDuplicateOf,
  });

  factory TimetableVersion.fromJson(Map<String, dynamic> json) {
    return TimetableVersion(
      sessionId: json['session_id'] as int,
      versionId: json['version_id'] as int,
      populationSize: json['population_size'] as int,
      generations: json['generations'] as int,
      bestViolation: json['best_violation'] as int,
      bestSoftScore: (json['best_soft_score'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      isDuplicateOf: json['is_duplicate_of'] as int?,
    );
  }

  // Helper to convert violation score to a health percentage (0 violations = 100%)
  double get healthPercentage {
    if (bestViolation == 0) return 100.0;
    if (bestViolation > 1000) return 0.0;
    return (1000 - bestViolation) / 10.0;
  }
}

class GenerationResult {
  final String status;
  final String message;
  final int? versionId;
  final Map<String, dynamic>? violations;

  GenerationResult({
    required this.status,
    required this.message,
    this.versionId,
    this.violations,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> json) {
    return GenerationResult(
      status: json['status'] as String,
      message: json['message'] as String,
      versionId: json['version_id'] as int?,
      violations: json['violations'] as Map<String, dynamic>?,
    );
  }
}

class ConflictLog {
  final String type;
  final int count;

  ConflictLog({required this.type, required this.count});

  factory ConflictLog.fromJson(Map<String, dynamic> json) {
    return ConflictLog(
      type: json['type'] as String,
      count: json['count'] as int,
    );
  }
}

class GenerationStatusData {
  final String status;
  final int attempt;
  final int maxAttempts;
  final int generation;
  final int maxGenerations;
  final int? bestViolation;
  final bool isFeasible;
  final List<ConflictLog> conflictLogs;
  final Map<String, dynamic>? feasibilityInfo;

  GenerationStatusData({
    required this.status,
    required this.attempt,
    required this.maxAttempts,
    required this.generation,
    required this.maxGenerations,
    this.bestViolation,
    required this.isFeasible,
    required this.conflictLogs,
    this.feasibilityInfo,
  });

  factory GenerationStatusData.fromJson(Map<String, dynamic> json) {
    return GenerationStatusData(
      status: json['status'] as String? ?? 'Idle',
      attempt: json['attempt'] as int? ?? 0,
      maxAttempts: json['max_attempts'] as int? ?? 5,
      generation: json['generation'] as int? ?? 0,
      maxGenerations: json['max_generations'] as int? ?? 0,
      bestViolation: json['best_violation'] as int?,
      isFeasible: json['is_feasible'] as bool? ?? false,
      conflictLogs: (json['conflict_logs'] as List<dynamic>?)
              ?.map((e) => ConflictLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      feasibilityInfo: json['feasibility_info'] as Map<String, dynamic>?,
    );
  }
}
