/// Plantilla de entrenamiento del usuario (contrato asumido de #121).
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

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercise'] as Map<String, dynamic>?;
    return RoutineExercise(
      exerciseId: json['exerciseId'] as String,
      exerciseName: (exercise?['name'] ?? json['exerciseName'] ?? '') as String,
      position: json['position'] as int,
      targetSets: json['targetSets'] as int,
      targetReps: json['targetReps'] as int,
    );
  }
}
