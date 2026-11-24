import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/exercises/data/exercise.dart';
import 'package:fit_track_360/features/exercises/data/exercises_api.dart';
import 'package:fit_track_360/features/exercises/presentation/widgets/exercise_media_view.dart';
import 'package:fit_track_360/features/workouts/domain/tracker_location_provider.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/presentation/tracker_session_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_workouts_repository.dart';

class _NoLocation implements TrackerLocationProvider {
  @override
  Future<TrackerGpsFix?> getApproximateLocation() async => null;
}

Map<String, Object?> _exerciseJson(String id, String name) => {
  'id': id,
  'name': name,
  'bodyPart': 'waist',
  'equipment': 'body weight',
  'target': 'abs',
  'imageFile': '$id.jpg',
  'attribution': 'Gym Visual',
};

/// Catálogo con un ejercicio por id; registra las rutas pedidas.
MockClient _catalog(List<String> paths) {
  return MockClient((request) async {
    paths.add(request.url.path + (request.url.hasQuery ? '?' : ''));
    final segments = request.url.pathSegments;
    final body = segments.last == 'exercises'
        ? {
            'items': [_exerciseJson('0001', 'Crunch')],
            'total': 1,
            'page': 1,
            'pageSize': 20,
          }
        : _exerciseJson(segments.last, 'Ejercicio ${segments.last}');
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });
}

const _crunch = Exercise(
  id: '0001',
  name: 'crunch',
  nameEs: 'Abdominal corto',
  bodyPart: 'waist',
  equipment: 'body weight',
  target: 'abs',
  imageFile: '0001.jpg',
  attribution: 'Gym Visual',
);

final _routineDraft = WorkoutSessionDraft(
  routineId: 'rutina-1',
  routineName: 'Pierna',
  startedAt: DateTime.utc(2026, 11, 10, 18),
  exercises: const [
    PlannedExercise(
      exerciseId: 'ej-b',
      exerciseName: 'Zancada',
      position: 1,
      targetSets: 1,
      targetReps: 12,
    ),
    PlannedExercise(
      exerciseId: 'ej-a',
      exerciseName: 'Sentadilla',
      position: 0,
      targetSets: 2,
      targetReps: 8,
    ),
  ],
);

Finder _scrollable() => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _scrollable().first);
  await tester.pumpAndSettle();
}

Future<void> _completeFirstSet(WidgetTester tester) async {
  await _scrollTo(tester, find.text('Serie 1'));
  final toggle = find.byTooltip('Marcar serie como completada').first;
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

/// Monta el tracker sobre una pantalla base para poder volver.
Future<void> _pumpTracker(
  WidgetTester tester, {
  TrackerSessionArgs? args,
  FakeWorkoutsRepository? repository,
  List<String>? paths,
}) async {
  final client = ApiClient(
    storage: FakeSessionStorage(),
    httpClient: _catalog(paths ?? []),
  );
  addTearDown(client.dispose);
  final router = GoRouter(
    initialLocation: '/app',
    routes: [
      GoRoute(
        path: '/app',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push(workoutTrackerRoute, extra: args),
            child: const Text('Inicio'),
          ),
        ),
      ),
      GoRoute(
        path: workoutTrackerRoute,
        builder: (context, state) => TrackerSessionPage(
          args: state.extra as TrackerSessionArgs?,
          workoutsRepository:
              repository ?? FakeWorkoutsRepository(sessions: const []),
          exercisesApi: ExercisesApi(client),
          locationProvider: _NoLocation(),
          apiClient: client,
        ),
      ),
      GoRoute(
        path: '/app/entrenamientos/:id',
        builder: (context, state) =>
            Text('Detalle ${state.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('Inicio'));
  await tester.pumpAndSettle();
}

/// Libera el tracker (y sus cronómetros) al terminar la prueba.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('sin argumentos pide elegir ejercicio y no toma el primero', (
    tester,
  ) async {
    final paths = <String>[];
    await _pumpTracker(tester, paths: paths);

    expect(find.text('Elige un ejercicio para empezar'), findsOneWidget);
    expect(find.text('Elegir ejercicio'), findsOneWidget);
    expect(find.text('Sesión activa'), findsNothing);
    expect(paths, isEmpty);
    await _unmount(tester);
  });

  testWidgets('al elegir en el selector inicia la sesión con ese ejercicio', (
    tester,
  ) async {
    await _pumpTracker(tester);

    await tester.tap(find.text('Elegir ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crunch'));
    await tester.pumpAndSettle();

    expect(find.text('Sesión activa'), findsOneWidget);
    expect(find.text('Crunch'), findsOneWidget);
    expect(find.text('Cambiar ejercicio'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('muestra etiquetas en español e imagen del catálogo', (
    tester,
  ) async {
    await _pumpTracker(
      tester,
      args: const TrackerSessionArgs(exercise: _crunch),
    );

    expect(find.text('Abdominal corto'), findsOneWidget);
    expect(find.text('Cintura'), findsOneWidget);
    expect(find.text('Abdominales'), findsOneWidget);
    expect(find.text('Peso corporal'), findsOneWidget);
    expect(find.text('waist'), findsNothing);
    expect(find.text('body weight'), findsNothing);
    expect(find.text('abs'), findsNothing);
    expect(find.byType(ExerciseMediaView), findsOneWidget);
    expect(find.text('Vista previa multimedia del ejercicio'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('los textos del tracker llevan acentos', (tester) async {
    await _pumpTracker(
      tester,
      args: const TrackerSessionArgs(exercise: _crunch),
    );

    expect(find.text('Sesión en curso'), findsOneWidget);
    await _scrollTo(tester, find.text('Sin ubicación capturada todavía'));
    expect(find.text('Sin ubicación capturada todavía'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('una rutina abre el tracker con todos sus ejercicios', (
    tester,
  ) async {
    final repository = FakeWorkoutsRepository(sessions: const []);
    await _pumpTracker(
      tester,
      args: TrackerSessionArgs(draft: _routineDraft),
      repository: repository,
    );

    expect(find.text('Ejercicio 1 de 2'), findsOneWidget);
    expect(find.text('Sentadilla'), findsOneWidget);
    expect(find.byType(ExerciseMediaView), findsOneWidget);

    await _completeFirstSet(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Siguiente ejercicio'),
      -250,
      scrollable: _scrollable().first,
    );
    await tester.ensureVisible(find.text('Siguiente ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente ejercicio'));
    await tester.pumpAndSettle();
    expect(find.text('Ejercicio 2 de 2'), findsOneWidget);
    expect(find.text('Zancada'), findsOneWidget);
    await _completeFirstSet(tester);
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Finalizar sesión'));
    await tester.tap(find.text('Finalizar sesión'));
    await tester.pumpAndSettle();

    final payload = repository.createdPayloads.single;
    expect(payload['routineId'], 'rutina-1');
    expect(payload['endedAt'], isNotNull);
    expect(payload['sets'], [
      {'exerciseId': 'ej-a', 'order': 1, 'weight': 0.0, 'reps': 8},
      {'exerciseId': 'ej-b', 'order': 2, 'weight': 0.0, 'reps': 12},
    ]);
    expect(find.text('Detalle created-1'), findsOneWidget);
  });

  group('salir con una sesión activa', () {
    testWidgets('el botón Volver pide confirmación', (tester) async {
      await _pumpTracker(
        tester,
        args: const TrackerSessionArgs(exercise: _crunch),
      );

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar la sesión?'), findsOneWidget);

      await tester.tap(find.text('Seguir entrenando'));
      await tester.pumpAndSettle();
      expect(find.text('Sesión activa'), findsOneWidget);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('el gesto de volver del sistema también pregunta', (
      tester,
    ) async {
      await _pumpTracker(
        tester,
        args: const TrackerSessionArgs(exercise: _crunch),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar la sesión?'), findsOneWidget);
      expect(find.text('Sesión activa'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('sin sesión iniciada sale sin preguntar', (tester) async {
      await _pumpTracker(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar la sesión?'), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
    });
  });
}
