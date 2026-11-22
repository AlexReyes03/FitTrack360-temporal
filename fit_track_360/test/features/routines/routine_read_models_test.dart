import 'package:fit_track_360/features/routines/data/routines_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutineSummary', () {
    test('cuenta ejercicios y series objetivo', () {
      final routine = RoutineSummary.fromJson({
        'id': 'r1',
        'name': ' Fuerza ',
        'notes': 'Día de empuje',
        'exercises': [
          {'exerciseId': 'e1', 'targetSets': 3},
          {'exerciseId': 'e2', 'targetSets': 4},
        ],
      });

      expect(routine.name, 'Fuerza');
      expect(routine.notes, 'Día de empuje');
      expect(routine.exerciseCount, 2);
      expect(routine.targetSetCount, 7);
    });

    test('oculta métricas cuando no hay ejercicios en la respuesta', () {
      final routine = RoutineSummary.fromJson({'id': 'r1', 'name': 'Pierna'});

      expect(routine.exerciseCount, isNull);
      expect(routine.targetSetCount, isNull);
      expect(routine.notes, isNull);
    });

    test('trata un texto vacío como campo ausente', () {
      final routine = RoutineSummary.fromJson({
        'id': 'r1',
        'name': 'Pierna',
        'notes': '   ',
      });

      expect(routine.notes, isNull);
    });
  });

  group('RoutineDetail', () {
    test('ordena los ejercicios por posición', () {
      final detail = RoutineDetail.fromJson({
        'id': 'r1',
        'name': 'Full body',
        'exercises': [
          {
            'exerciseId': 'e3',
            'position': 3,
            'exercise': {'name': 'Peso muerto'},
          },
          {
            'exerciseId': 'e1',
            'position': 1,
            'exercise': {'name': 'Sentadilla'},
          },
          {
            'exerciseId': 'e2',
            'position': 2,
            'exercise': {'name': 'Press banca'},
          },
        ],
      });

      expect(detail.exercises.map((item) => item.displayName), [
        'Sentadilla',
        'Press banca',
        'Peso muerto',
      ]);
    });

    test('mantiene al final los ejercicios sin posición', () {
      final detail = RoutineDetail.fromJson({
        'id': 'r1',
        'name': 'Full body',
        'exercises': [
          {'exerciseId': 'e2', 'exerciseName': 'Remo'},
          {'exerciseId': 'e1', 'position': 1, 'exerciseName': 'Sentadilla'},
        ],
      });

      expect(detail.exercises.map((item) => item.displayName), [
        'Sentadilla',
        'Remo',
      ]);
    });

    test('usa un nombre genérico si falta el ejercicio', () {
      final detail = RoutineDetail.fromJson({
        'id': 'r1',
        'name': 'Full body',
        'exercises': [
          {'exerciseId': 'e1', 'position': 1},
        ],
      });

      expect(detail.exercises.single.displayName, 'Ejercicio');
    });

    test('conserva notas y ejercicios opcionales', () {
      final detail = RoutineDetail.fromJson({
        'id': 'r1',
        'name': 'Full body',
        'notes': null,
        'exercises': null,
      });

      expect(detail.notes, isNull);
      expect(detail.exercises, isEmpty);
    });
  });

  group('RoutineExerciseSummary.targetLabel', () {
    test('combina series y repeticiones', () {
      const exercise = RoutineExerciseSummary(targetSets: 3, targetReps: 12);

      expect(exercise.targetLabel, '3 series × 12 reps');
    });

    test('usa singular cuando corresponde', () {
      const exercise = RoutineExerciseSummary(targetSets: 1, targetReps: 1);

      expect(exercise.targetLabel, '1 serie × 1 rep');
    });

    test('muestra solo el objetivo disponible', () {
      expect(
        const RoutineExerciseSummary(targetSets: 4).targetLabel,
        '4 series',
      );
      expect(
        const RoutineExerciseSummary(targetReps: 10).targetLabel,
        '10 reps',
      );
    });

    test('no muestra objetivo sin datos', () {
      expect(const RoutineExerciseSummary().targetLabel, isNull);
    });
  });
}
