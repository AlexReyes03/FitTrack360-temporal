import '../domain/workout_set.dart';

class WorkoutSession {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Series de la sesión. El API actual todavía no las devuelve: si llegan
  /// en `sets` se leen; si no, la lista queda vacía.
  final List<WorkoutSet> sets;

  const WorkoutSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.sets = const [],
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? const [];
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
      sets: List.unmodifiable(
        rawSets.cast<Map<String, dynamic>>().map(
          (item) => WorkoutSet(
            exerciseName: item['exerciseName'] as String,
            weightKg: (item['weightKg'] as num).toDouble(),
            reps: (item['reps'] as num).toInt(),
          ),
        ),
      ),
    );
  }
}
