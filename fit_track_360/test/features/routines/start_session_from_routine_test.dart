import 'package:fit_track_360/features/routines/domain/routine.dart';
import 'package:fit_track_360/features/routines/domain/start_session_from_routine.dart';
import 'package:flutter_test/flutter_test.dart';

Routine _routine({List<RoutineExercise> exercises = const []}) => Routine(
  id: 'rutina-1',
  name: 'Pierna',
  notes: 'Calentar antes',
  exercises: exercises,
);

const _sentadilla = RoutineExercise(
  exerciseId: 'ej-a',
  exerciseName: 'Sentadilla',
  position: 0,
  targetSets: 4,
  targetReps: 8,
);

void main() {
  final now = DateTime.utc(2026, 11, 10, 18);
  final useCase = StartSessionFromRoutine(clock: () => now);

  group('StartSessionFromRoutine', () {
    test('precarga los ejercicios en el orden de la rutina', () {
      final routine = _routine(
        exercises: const [
          RoutineExercise(
            exerciseId: 'ej-c',
            exerciseName: 'Peso muerto',
            position: 2,
            targetSets: 3,
            targetReps: 5,
          ),
          _sentadilla,
          RoutineExercise(
            exerciseId: 'ej-b',
            exerciseName: 'Zancada',
            position: 1,
            targetSets: 3,
            targetReps: 12,
          ),
        ],
      );

      final draft = useCase(routine);

      expect(draft.exercises.map((e) => e.exerciseId), [
        'ej-a',
        'ej-b',
        'ej-c',
      ]);
      expect(draft.exercises.map((e) => e.position), [0, 1, 2]);
    });

    test('copia sets y reps objetivo y los datos de la rutina', () {
      final draft = useCase(_routine(exercises: const [_sentadilla]));

      expect(draft.routineId, 'rutina-1');
      expect(draft.routineName, 'Pierna');
      expect(draft.startedAt, now);
      expect(draft.notes, 'Calentar antes');
      final exercise = draft.exercises.single;
      expect(exercise.exerciseName, 'Sentadilla');
      expect(exercise.targetSets, 4);
      expect(exercise.targetReps, 8);
    });

    test('el borrador produce el payload actual de POST /workouts', () {
      final draft = useCase(_routine(exercises: const [_sentadilla]));

      expect(draft.toCreateWorkoutPayload(), {
        'startedAt': '2026-11-10T18:00:00.000Z',
        'notes': 'Calentar antes',
      });
    });

    test('una rutina vacía no inicia sesión', () {
      expect(
        () => useCase(_routine()),
        throwsA(
          isA<EmptyRoutineException>().having(
            (e) => e.message,
            'message',
            'La rutina no tiene ejercicios. Agrega al menos uno para iniciar.',
          ),
        ),
      );
      expect(StartSessionFromRoutine.canStart(_routine()), isFalse);
    });

    test('el borrador es inmutable', () {
      final draft = useCase(_routine(exercises: const [_sentadilla]));

      expect(() => draft.exercises.clear(), throwsUnsupportedError);
    });
  });

  group('Routine.fromJson', () {
    test('lee el contrato asumido de GET /routines/:id', () {
      final routine = Routine.fromJson({
        'id': 'rutina-1',
        'name': 'Pierna',
        'notes': null,
        'exercises': [
          {
            'exerciseId': 'ej-a',
            'position': 0,
            'targetSets': 4,
            'targetReps': 8,
            'exercise': {'id': 'ej-a', 'name': 'Sentadilla'},
          },
        ],
      });

      expect(routine.notes, isNull);
      expect(routine.exercises.single.exerciseName, 'Sentadilla');
      expect(routine.exercises.single.targetSets, 4);
      expect(StartSessionFromRoutine.canStart(routine), isTrue);
    });
  });
}
