class WorkoutSession {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
