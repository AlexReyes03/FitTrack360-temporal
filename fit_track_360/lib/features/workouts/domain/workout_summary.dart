import '../data/workout_session.dart';

/// Resumen derivado de una sesión guardada: duración, volumen, series,
/// ejercicios (en orden de aparición, con su número de series) y notas.
class WorkoutSummary {
  final DateTime startedAt;

  /// Null mientras la sesión no tiene hora de fin.
  final Duration? duration;
  final double volumeKg;
  final int setCount;
  final List<String> exercises;
  final Map<String, int> setsPerExercise;
  final String? notes;

  const WorkoutSummary({
    required this.startedAt,
    required this.duration,
    required this.volumeKg,
    required this.setCount,
    required this.exercises,
    required this.setsPerExercise,
    required this.notes,
  });

  factory WorkoutSummary.of(WorkoutSession session) {
    final setsPerExercise = <String, int>{};
    var volume = 0.0;
    for (final set in session.sets) {
      volume += set.volumeKg;
      setsPerExercise.update(
        set.exerciseName,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return WorkoutSummary(
      startedAt: session.startedAt,
      duration: session.endedAt?.difference(session.startedAt),
      volumeKg: volume,
      setCount: session.sets.length,
      exercises: List.unmodifiable(setsPerExercise.keys),
      setsPerExercise: Map.unmodifiable(setsPerExercise),
      notes: session.notes,
    );
  }
}

/// Diferencias de la sesión actual contra la anterior (actual - anterior).
class WorkoutComparison {
  final DateTime previousStartedAt;

  /// Null si alguna de las dos sesiones no tiene duración.
  final Duration? durationDelta;
  final double volumeDeltaKg;
  final int setCountDelta;

  const WorkoutComparison({
    required this.previousStartedAt,
    required this.durationDelta,
    required this.volumeDeltaKg,
    required this.setCountDelta,
  });

  factory WorkoutComparison.between(
    WorkoutSummary current,
    WorkoutSummary previous,
  ) {
    final currentDuration = current.duration;
    final previousDuration = previous.duration;
    return WorkoutComparison(
      previousStartedAt: previous.startedAt,
      durationDelta: currentDuration == null || previousDuration == null
          ? null
          : currentDuration - previousDuration,
      volumeDeltaKg: current.volumeKg - previous.volumeKg,
      setCountDelta: current.setCount - previous.setCount,
    );
  }
}

/// La sesión más reciente que empezó antes de [current], o null si no hay.
WorkoutSession? findPreviousSession(
  List<WorkoutSession> sessions,
  WorkoutSession current,
) {
  WorkoutSession? previous;
  for (final session in sessions) {
    if (session.id == current.id) continue;
    if (!session.startedAt.isBefore(current.startedAt)) continue;
    if (previous == null || session.startedAt.isAfter(previous.startedAt)) {
      previous = session;
    }
  }
  return previous;
}
