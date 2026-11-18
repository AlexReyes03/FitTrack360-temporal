import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(List<Map<String, dynamic>> sets) => {
  'id': 's1',
  'userId': 'u1',
  'startedAt': '2026-11-04T10:00:00.000Z',
  'endedAt': '2026-11-04T11:00:00.000Z',
  'notes': null,
  'createdAt': '2026-11-04T10:00:00.000Z',
  'updatedAt': '2026-11-04T11:00:00.000Z',
  'sets': sets,
};

void main() {
  group('WorkoutSession.fromJson con series', () {
    test('lee el peso del campo weight que expone el API', () {
      final parsed = WorkoutSession.fromJson(
        _json([
          {'exerciseName': 'Sentadilla', 'weight': 80, 'reps': 10},
        ]),
      );

      expect(parsed.sets.single.weightKg, 80);
      expect(parsed.sets.single.volumeKg, 800);
    });

    test('acepta la respuesta real del API con weight y weightKg', () {
      final parsed = WorkoutSession.fromJson(
        _json([
          {
            'id': 'set1',
            'sessionId': 's1',
            'exerciseId': '0001',
            'exerciseName': 'Sentadilla',
            'order': 1,
            'weight': 62.5,
            'weightKg': 62.5,
            'reps': 8,
            'volume': 500,
            'rpe': null,
            'rir': null,
            'createdAt': '2026-11-04T10:05:00.000Z',
            'updatedAt': '2026-11-04T10:05:00.000Z',
          },
        ]),
      );

      expect(parsed.sets.single.exerciseName, 'Sentadilla');
      expect(parsed.sets.single.weightKg, 62.5);
      expect(parsed.sets.single.reps, 8);
    });

    test('peso nulo en ejercicios de peso corporal no lanza excepción', () {
      final parsed = WorkoutSession.fromJson(
        _json([
          {
            'exerciseName': 'Dominadas',
            'weight': null,
            'weightKg': null,
            'reps': 8,
          },
        ]),
      );

      expect(parsed.sets.single.weightKg, isNull);
      expect(parsed.sets.single.volumeKg, 0);
      expect(parsed.sets.single.reps, 8);
    });

    test('peso ausente se interpreta como sin peso', () {
      final parsed = WorkoutSession.fromJson(
        _json([
          {'exerciseName': 'Lagartijas', 'reps': 15},
        ]),
      );

      expect(parsed.sets.single.weightKg, isNull);
      expect(parsed.sets.single.volumeKg, 0);
    });

    test('sin nombre de ejercicio en el catálogo usa un texto genérico', () {
      final parsed = WorkoutSession.fromJson(
        _json([
          {'exerciseId': '0001', 'exerciseName': null, 'weight': 20, 'reps': 5},
        ]),
      );

      expect(parsed.sets.single.exerciseName, 'Ejercicio sin nombre');
    });
  });
}
