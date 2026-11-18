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

  /// Copia con el inicio y las notas que la persona ajustó en el formulario.
  WorkoutSessionDraft edited({
    required DateTime startedAt,
    required String notes,
  }) => WorkoutSessionDraft(
    routineId: routineId,
    routineName: routineName,
    startedAt: startedAt,
    notes: notes,
    exercises: exercises,
  );

  /// Cuerpo de `POST /workouts` según `CreateWorkoutDto` del API.
  ///
  /// Cada ejercicio planeado se expande en `targetSets` series con
  /// `reps = targetReps` y `weight = 0` (sin carga registrada aún), en el
  /// orden de la rutina y con `order` consecutivo desde 1, igual que
  /// `POST /routines/:id/start`. El nombre del ejercicio no viaja: el API lo
  /// resuelve por `exerciseId`.
  Map<String, dynamic> toCreateWorkoutPayload() {
    final ordered = [...exercises]
      ..sort((a, b) => a.position.compareTo(b.position));
    var order = 0;
    final sets = [
      for (final exercise in ordered)
        for (var i = 0; i < exercise.targetSets; i++)
          {
            'exerciseId': exercise.exerciseId,
            'order': ++order,
            'weight': 0,
            'reps': exercise.targetReps,
          },
    ];
    final trimmedNotes = notes?.trim();
    return {
      if (routineId != null) 'routineId': routineId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      if (trimmedNotes != null && trimmedNotes.isNotEmpty)
        'notes': trimmedNotes,
      if (sets.isNotEmpty) 'sets': sets,
    };
  }
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
