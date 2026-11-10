/// Borrador de una sesión de entrenamiento aún no persistida.
///
/// Se origina desde una rutina y lleva los ejercicios planeados en orden.
class WorkoutSessionDraft {
  final String? routineId;
  final String? routineName;
  final DateTime startedAt;
  final String? notes;
  final List<PlannedExercise> exercises;

  WorkoutSessionDraft({
    this.routineId,
    this.routineName,
    required this.startedAt,
    this.notes,
    required List<PlannedExercise> exercises,
  }) : exercises = List.unmodifiable(exercises);

  /// Cuerpo compatible con el `CreateWorkoutDto` actual de `POST /workouts`.
  /// Cuando #121 agregue `routineId` y series, se extiende aquí.
  Map<String, dynamic> toCreateWorkoutPayload() => {
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
  };
}

/// Ejercicio precargado en el borrador con su objetivo de series y reps.
class PlannedExercise {
  final String exerciseId;
  final String exerciseName;
  final int position;
  final int targetSets;
  final int targetReps;

  const PlannedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.position,
    required this.targetSets,
    required this.targetReps,
  });
}
