import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/presentation/workouts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorkoutsApi implements WorkoutsApi {
  @override
  Future<List<WorkoutSession>> list() async => const [];

  @override
  Future<WorkoutSession> create({required DateTime startedAt, String? notes}) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('la pantalla de sesión muestra el borrador de la rutina', (
    tester,
  ) async {
    final draft = WorkoutSessionDraft(
      routineId: 'rutina-1',
      routineName: 'Pierna',
      startedAt: DateTime.utc(2026, 11, 10, 18),
      exercises: const [
        PlannedExercise(
          exerciseId: 'ej-a',
          exerciseName: 'Sentadilla',
          position: 0,
          targetSets: 4,
          targetReps: 8,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(api: _FakeWorkoutsApi(), draft: draft),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rutina: Pierna'), findsOneWidget);
    expect(find.text('Sentadilla'), findsOneWidget);
    expect(find.text('4 series × 8 reps'), findsOneWidget);
  });

  testWidgets('sin borrador la pantalla conserva su uso actual', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: WorkoutsPage(api: _FakeWorkoutsApi())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Rutina:'), findsNothing);
    expect(find.text('Crear sesión'), findsOneWidget);
  });
}
