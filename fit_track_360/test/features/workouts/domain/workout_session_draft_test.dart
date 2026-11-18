import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:flutter_test/flutter_test.dart';

final _startedAt = DateTime.utc(2026, 11, 10, 18);

WorkoutSessionDraft _draft({
  String? routineId = 'rutina-1',
  String? notes = 'Calentar antes',
  List<PlannedExercise> exercises = const [
    PlannedExercise(
      exerciseId: 'ej-b',
      exerciseName: 'Zancada',
      position: 1,
      targetSets: 2,
      targetReps: 12,
    ),
    PlannedExercise(
      exerciseId: 'ej-a',
      exerciseName: 'Sentadilla',
      position: 0,
      targetSets: 3,
      targetReps: 8,
    ),
  ],
}) => WorkoutSessionDraft(
  routineId: routineId,
  routineName: 'Pierna',
  startedAt: _startedAt,
  notes: notes,
  exercises: exercises,
);

void main() {
  group('WorkoutSessionDraft.toCreateWorkoutPayload', () {
    test('incluye routineId, inicio, notas y las series planeadas', () {
      expect(_draft().toCreateWorkoutPayload(), {
        'routineId': 'rutina-1',
        'startedAt': '2026-11-10T18:00:00.000Z',
        'notes': 'Calentar antes',
        'sets': [
          {'exerciseId': 'ej-a', 'order': 1, 'weight': 0, 'reps': 8},
          {'exerciseId': 'ej-a', 'order': 2, 'weight': 0, 'reps': 8},
          {'exerciseId': 'ej-a', 'order': 3, 'weight': 0, 'reps': 8},
          {'exerciseId': 'ej-b', 'order': 4, 'weight': 0, 'reps': 12},
          {'exerciseId': 'ej-b', 'order': 5, 'weight': 0, 'reps': 12},
        ],
      });
    });

    test('sin rutina ni ejercicios envía solo inicio y notas', () {
      final payload = _draft(
        routineId: null,
        exercises: const [],
      ).toCreateWorkoutPayload();

      expect(payload, {
        'startedAt': '2026-11-10T18:00:00.000Z',
        'notes': 'Calentar antes',
      });
    });

    test('omite notas vacías y recorta las que tienen espacios', () {
      expect(
        _draft(notes: '   ').toCreateWorkoutPayload().containsKey('notes'),
        isFalse,
      );
      expect(
        _draft(notes: '  Buen día ').toCreateWorkoutPayload()['notes'],
        'Buen día',
      );
    });
  });

  group('WorkoutSessionDraft.edited', () {
    test('aplica inicio y notas del formulario y conserva la rutina', () {
      final edited = _draft().edited(
        startedAt: DateTime.utc(2026, 11, 11, 7, 30),
        notes: 'Sin calentar',
      );

      expect(edited.routineId, 'rutina-1');
      expect(edited.exercises, hasLength(2));
      final payload = edited.toCreateWorkoutPayload();
      expect(payload['startedAt'], '2026-11-11T07:30:00.000Z');
      expect(payload['notes'], 'Sin calentar');
      expect(payload['sets'], hasLength(5));
    });
  });
}
