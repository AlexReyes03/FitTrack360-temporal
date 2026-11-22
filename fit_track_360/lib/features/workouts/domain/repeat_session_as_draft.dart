import '../data/workout_session.dart';
import 'workout_session_draft.dart';
import 'workout_set.dart';

class WorkoutSessionNotRepeatableException implements Exception {
  const WorkoutSessionNotRepeatableException();
}

class RepeatSessionAsDraft {
  RepeatSessionAsDraft({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  WorkoutSessionDraft call(WorkoutSession session) {
    final ordered = <({int index, WorkoutSet set})>[];
    for (var index = 0; index < session.sets.length; index++) {
      final set = session.sets[index];
      final exerciseId = set.exerciseId?.trim();
      if (exerciseId == null || exerciseId.isEmpty || set.reps <= 0) {
        throw const WorkoutSessionNotRepeatableException();
      }
      ordered.add((index: set.order ?? index, set: set));
    }
    if (ordered.isEmpty) {
      throw const WorkoutSessionNotRepeatableException();
    }
    ordered.sort((a, b) => a.index.compareTo(b.index));

    final groups = <String, List<WorkoutSet>>{};
    for (final item in ordered) {
      groups.putIfAbsent(item.set.exerciseId!, () => []).add(item.set);
    }

    var position = 0;
    final exercises = [
      for (final entry in groups.entries)
        PlannedExercise(
          exerciseId: entry.key,
          exerciseName: entry.value.first.exerciseName,
          position: position++,
          targetSets: entry.value.length,
          targetReps: entry.value.first.reps,
        ),
    ];
    final sets = [
      for (var index = 0; index < ordered.length; index++)
        PlannedSet(
          exerciseId: ordered[index].set.exerciseId!,
          order: index + 1,
          weightKg: ordered[index].set.weightKg ?? 0,
          reps: ordered[index].set.reps,
        ),
    ];

    return WorkoutSessionDraft(
      startedAt: _clock(),
      exercises: exercises,
      sets: sets,
    );
  }
}
