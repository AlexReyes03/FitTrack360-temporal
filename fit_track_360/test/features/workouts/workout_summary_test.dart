import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/domain/workout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession session({
  String id = 's1',
  required DateTime startedAt,
  DateTime? endedAt,
  String? notes,
  List<WorkoutSet> sets = const [],
}) {
  return WorkoutSession(
    id: id,
    userId: 'u1',
    startedAt: startedAt,
    endedAt: endedAt,
    notes: notes,
    createdAt: startedAt,
    updatedAt: startedAt,
    sets: sets,
  );
}

void main() {
  final start = DateTime.utc(2026, 11, 4, 10);

  group('WorkoutSummary.of', () {
    test('calcula duración, volumen, series y ejercicios guardados', () {
      final summary = WorkoutSummary.of(
        session(
          startedAt: start,
          endedAt: start.add(const Duration(minutes: 75)),
          notes: 'Buen día',
          sets: const [
            WorkoutSet(exerciseName: 'Sentadilla', weightKg: 100, reps: 5),
            WorkoutSet(exerciseName: 'Sentadilla', weightKg: 100, reps: 5),
            WorkoutSet(exerciseName: 'Press banca', weightKg: 62.5, reps: 8),
          ],
        ),
      );

      expect(summary.duration, const Duration(minutes: 75));
      expect(summary.volumeKg, 1500);
      expect(summary.setCount, 3);
      expect(summary.exercises, ['Sentadilla', 'Press banca']);
      expect(summary.notes, 'Buen día');
    });

    test('sin fin la duración es null y sin series el volumen es 0', () {
      final summary = WorkoutSummary.of(session(startedAt: start));

      expect(summary.duration, isNull);
      expect(summary.volumeKg, 0);
      expect(summary.setCount, 0);
      expect(summary.exercises, isEmpty);
    });
  });

  group('findPreviousSession', () {
    test('elige la más reciente anterior a la actual', () {
      final current = session(id: 'c', startedAt: start);
      final older = session(
        id: 'o',
        startedAt: start.subtract(const Duration(days: 5)),
      );
      final previous = session(
        id: 'p',
        startedAt: start.subtract(const Duration(days: 1)),
      );
      final later = session(
        id: 'l',
        startedAt: start.add(const Duration(days: 1)),
      );

      expect(
        findPreviousSession([later, current, older, previous], current)?.id,
        'p',
      );
    });

    test('devuelve null si no hay sesión anterior', () {
      final current = session(id: 'c', startedAt: start);
      expect(findPreviousSession([current], current), isNull);
    });
  });

  test('WorkoutComparison.between calcula las diferencias', () {
    final current = WorkoutSummary.of(
      session(
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 60)),
        sets: const [
          WorkoutSet(exerciseName: 'Remo', weightKg: 50, reps: 10),
          WorkoutSet(exerciseName: 'Remo', weightKg: 50, reps: 10),
        ],
      ),
    );
    final previous = WorkoutSummary.of(
      session(
        startedAt: start.subtract(const Duration(days: 2)),
        endedAt: start
            .subtract(const Duration(days: 2))
            .add(const Duration(minutes: 45)),
        sets: const [WorkoutSet(exerciseName: 'Remo', weightKg: 40, reps: 10)],
      ),
    );

    final comparison = WorkoutComparison.between(current, previous);

    expect(
      comparison.previousStartedAt,
      start.subtract(const Duration(days: 2)),
    );
    expect(comparison.durationDelta, const Duration(minutes: 15));
    expect(comparison.volumeDeltaKg, 600);
    expect(comparison.setCountDelta, 1);
  });

  test('WorkoutSession.fromJson lee las series si el API las incluye', () {
    final parsed = WorkoutSession.fromJson({
      'id': 's1',
      'userId': 'u1',
      'startedAt': '2026-11-04T10:00:00.000Z',
      'endedAt': null,
      'notes': null,
      'createdAt': '2026-11-04T10:00:00.000Z',
      'updatedAt': '2026-11-04T10:00:00.000Z',
      'sets': [
        {'exerciseName': 'Peso muerto', 'weightKg': 120, 'reps': 3},
      ],
    });

    expect(parsed.sets.single.exerciseName, 'Peso muerto');
    expect(parsed.sets.single.weightKg, 120);
    expect(parsed.sets.single.reps, 3);
  });
}
