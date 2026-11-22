import '../domain/workout_set.dart';

class WorkoutSession {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Series de la sesión que el API devuelve en `sets`; si no llegan, la
  /// lista queda vacía.
  final List<WorkoutSet> sets;

  const WorkoutSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.location,
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
      location: json['location'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sets: List.unmodifiable(
        rawSets.cast<Map<String, dynamic>>().map(_setFromJson),
      ),
    );
  }

  /// El API manda el peso en `weight` (y lo repite en `weightKg`). Ambos
  /// pueden faltar o ser nulos en ejercicios de peso corporal.
  static WorkoutSet _setFromJson(Map<String, dynamic> item) {
    final weight = item['weight'] ?? item['weightKg'];
    final reps = item['reps'];
    final order = item['order'];
    return WorkoutSet(
      exerciseId: item['exerciseId'] as String?,
      exerciseName: item['exerciseName'] as String? ?? 'Ejercicio sin nombre',
      order: order is num ? order.toInt() : null,
      weightKg: weight is num ? weight.toDouble() : null,
      reps: reps is num ? reps.toInt() : 0,
    );
  }
}
