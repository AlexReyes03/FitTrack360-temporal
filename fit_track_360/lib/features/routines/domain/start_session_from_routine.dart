import '../../workouts/domain/workout_session_draft.dart';
import 'routine.dart';

/// Error de dominio: una rutina sin ejercicios no inicia sesión.
class EmptyRoutineException implements Exception {
  final String message =
      'La rutina no tiene ejercicios. Agrega al menos uno para iniciar.';

  @override
  String toString() => message;
}

/// Caso de uso puro: convierte una rutina en el borrador de una sesión.
class StartSessionFromRoutine {
  final DateTime Function() _clock;

  StartSessionFromRoutine({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static bool canStart(Routine routine) => !routine.isEmpty;

  WorkoutSessionDraft call(Routine routine) {
    if (!canStart(routine)) throw EmptyRoutineException();

    final ordered = [...routine.exercises]
      ..sort((a, b) => a.position.compareTo(b.position));

    return WorkoutSessionDraft(
      routineId: routine.id,
      routineName: routine.name,
      startedAt: _clock(),
      notes: routine.notes,
      exercises: [
        for (final item in ordered)
          PlannedExercise(
            exerciseId: item.exerciseId,
            exerciseName: item.exerciseName,
            position: item.position,
            targetSets: item.targetSets,
            targetReps: item.targetReps,
          ),
      ],
    );
  }
}
