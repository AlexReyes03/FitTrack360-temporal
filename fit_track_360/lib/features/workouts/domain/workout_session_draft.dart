/// Borrador de una sesión de entrenamiento aún no persistida.
///
/// Se origina desde una rutina y lleva los ejercicios planeados en orden.
class WorkoutSessionDraft {
  final String? routineId;
  final String? routineName;
  final DateTime startedAt;
  final String? notes;
  final List<PlannedExercise> exercises;

  /// Series exactas de una sesión repetida; null si se expanden desde
  /// [exercises] como en una rutina.
  final List<PlannedSet>? sets;

  WorkoutSessionDraft({
    this.routineId,
    this.routineName,
    required this.startedAt,
    this.notes,
    required List<PlannedExercise> exercises,
    List<PlannedSet>? sets,
  }) : exercises = List.unmodifiable(exercises),
       sets = sets == null ? null : List.unmodifiable(sets);

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
    sets: sets,
  );

  /// Cuerpo de `POST /workouts` según `CreateWorkoutDto` del API.
  ///
  /// Si [sets] viene de una sesión repetida se envían esas series; si no,
  /// cada ejercicio planeado se expande en `targetSets` series sin carga,
  /// igual que `POST /routines/:id/start`.
  Map<String, dynamic> toCreateWorkoutPayload() {
    final ordered = [...exercises]
      ..sort((a, b) => a.position.compareTo(b.position));
    var order = 0;
    final exactSets = sets;
    final orderedSets = exactSets == null
        ? null
        : ([...exactSets]..sort((a, b) => a.order.compareTo(b.order)));
    final payloadSets = orderedSets != null
        ? [
            for (final set in orderedSets)
              {
                'exerciseId': set.exerciseId,
                'order': ++order,
                'weight': set.weightKg,
                'reps': set.reps,
              },
          ]
        : [
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
      if (payloadSets.isNotEmpty) 'sets': payloadSets,
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

/// Serie exacta de una sesión repetida, conservando peso y repeticiones.
class PlannedSet {
  final String exerciseId;
  final int order;
  final double weightKg;
  final int reps;

  const PlannedSet({
    required this.exerciseId,
    required this.order,
    required this.weightKg,
    required this.reps,
  });
}
