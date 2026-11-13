import 'package:fit_track_360/features/routines/domain/routine.dart';
import 'package:fit_track_360/features/routines/presentation/start_session_button.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _fullRoutine = Routine(
  id: 'rutina-1',
  name: 'Pierna',
  exercises: [
    RoutineExercise(
      exerciseId: 'ej-b',
      exerciseName: 'Zancada',
      position: 1,
      targetSets: 3,
      targetReps: 12,
    ),
    RoutineExercise(
      exerciseId: 'ej-a',
      exerciseName: 'Sentadilla',
      position: 0,
      targetSets: 4,
      targetReps: 8,
    ),
  ],
);

const _emptyRoutine = Routine(id: 'rutina-2', name: 'Vacía', exercises: []);

const _emptyMessage =
    'La rutina no tiene ejercicios. Agrega al menos uno para iniciar.';

Future<WorkoutSessionDraft?> _tapWithRouter(
  WidgetTester tester,
  Routine routine,
) async {
  WorkoutSessionDraft? received;
  final router = GoRouter(
    initialLocation: '/rutina',
    routes: [
      GoRoute(
        path: '/rutina',
        builder: (context, state) =>
            Scaffold(body: StartSessionButton(routine: routine)),
      ),
      GoRoute(
        path: '/app/entrenamientos',
        builder: (context, state) {
          received = state.extra as WorkoutSessionDraft?;
          return const Scaffold(body: Text('Pantalla de sesión'));
        },
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pumpAndSettle();
  return received;
}

void main() {
  testWidgets('navega a la sesión con el borrador precargado', (tester) async {
    final draft = await _tapWithRouter(tester, _fullRoutine);

    expect(find.text('Pantalla de sesión'), findsOneWidget);
    expect(draft, isNotNull);
    expect(draft!.routineId, 'rutina-1');
    expect(draft.exercises.map((e) => e.exerciseName), [
      'Sentadilla',
      'Zancada',
    ]);
  });

  testWidgets('con rutina vacía muestra el error y no navega', (tester) async {
    final draft = await _tapWithRouter(tester, _emptyRoutine);

    expect(draft, isNull);
    expect(find.text('Pantalla de sesión'), findsNothing);
    expect(find.text(_emptyMessage), findsOneWidget);
  });

  testWidgets('acepta un onStarted propio para reutilizarse', (tester) async {
    WorkoutSessionDraft? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StartSessionButton(
            routine: _fullRoutine,
            onStarted: (draft) => received = draft,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(received?.exercises.first.targetSets, 4);
    expect(find.text(_emptyMessage), findsNothing);
  });
}
