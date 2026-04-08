class SessionModel {
  final int sessionId;
  final String name;
  final bool isActive;

  SessionModel({
    required this.sessionId,
    required this.name,
    this.isActive = true,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      sessionId: json['session_id'] as int,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'name': name,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionModel && other.sessionId == sessionId;
  }

  @override
  int get hashCode => sessionId.hashCode;
}
