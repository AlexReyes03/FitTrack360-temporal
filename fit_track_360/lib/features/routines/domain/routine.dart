/// Plantilla de entrenamiento del usuario (`GET /routines/:id`).
class Routine {
  final String id;
  final String name;
  final String? notes;
  final List<RoutineExercise> exercises;

  const Routine({
    required this.id,
    required this.name,
    this.notes,
    required this.exercises,
  });

  bool get isEmpty => exercises.isEmpty;

  factory Routine.fromJson(Map<String, dynamic> json) {
    final items = (json['exercises'] as List<dynamic>? ?? const [])
        .map((item) => RoutineExercise.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      exercises: List.unmodifiable(items),
    );
  }
}

/// Ejercicio dentro de una rutina con su posición y objetivo de series y reps.
class RoutineExercise {
  final String exerciseId;
  final String exerciseName;
  final int position;
  final int targetSets;
  final int targetReps;

  const RoutineExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.position,
    required this.targetSets,
    required this.targetReps,
  });

  /// Acepta `exerciseId` plano (forma actual de `GET /routines/:id`) y,
  /// como respaldo, `exercise: {id, name}` cuando el API incluya la relación.
  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercise'];
    final nested = exercise is Map<String, dynamic> ? exercise : null;
    final exerciseId = json['exerciseId'] ?? nested?['id'];
    if (exerciseId is! String || exerciseId.isEmpty) {
      throw const FormatException('El ejercicio de la rutina no tiene id');
    }
    final name = nested?['name'] ?? json['exerciseName'];
    return RoutineExercise(
      exerciseId: exerciseId,
      exerciseName: name is String ? name : '',
      position: (json['position'] as num).toInt(),
      targetSets: (json['targetSets'] as num).toInt(),
      targetReps: (json['targetReps'] as num).toInt(),
    );
  }
}
