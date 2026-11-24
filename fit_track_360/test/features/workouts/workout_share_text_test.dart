import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/domain/workout_summary.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_share_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'comparte solo los datos del resumen y omite notas e identificadores',
    () {
      final start = DateTime.utc(2026, 11, 4, 10);
      final summary = WorkoutSummary.of(
        WorkoutSession(
          id: 'sesion-privada',
          userId: 'usuario-privado',
          startedAt: start,
          endedAt: start.add(const Duration(minutes: 60)),
          notes: 'correo@ejemplo.com token secreto',
          createdAt: start,
          updatedAt: start,
          sets: const [
            WorkoutSet(
              exerciseId: 'ej-a',
              exerciseName: 'Sentadilla',
              order: 1,
              weightKg: 100,
              reps: 5,
            ),
            WorkoutSet(
              exerciseId: 'ej-b',
              exerciseName: 'Press banca',
              order: 2,
              weightKg: 60,
              reps: 10,
            ),
          ],
        ),
      );

      final text = buildWorkoutShareText(summary);

      expect(text, contains('Duración: 1 h 0 min'));
      expect(text, contains('Volumen: 1100 kg'));
      expect(text, contains('Series: 2'));
      expect(text, contains('- Sentadilla: 1 serie'));
      expect(text, contains('- Press banca: 1 serie'));
      expect(text, isNot(contains('correo@ejemplo.com')));
      expect(text, isNot(contains('token secreto')));
      expect(text, isNot(contains('sesion-privada')));
      expect(text, isNot(contains('usuario-privado')));
      expect(text, isNot(contains('ej-a')));
    },
  );

  test('sin ejercicios no añade la lista', () {
    final summary = WorkoutSummary.of(
      WorkoutSession(
        id: 's1',
        userId: 'u1',
        startedAt: DateTime.utc(2026, 11, 4, 10),
        endedAt: null,
        notes: null,
        createdAt: DateTime.utc(2026, 11, 4, 10),
        updatedAt: DateTime.utc(2026, 11, 4, 10),
      ),
    );

    final text = buildWorkoutShareText(summary);

    expect(text, contains('Duración: Sin registrar'));
    expect(text, isNot(contains('Ejercicios:')));
  });
}
