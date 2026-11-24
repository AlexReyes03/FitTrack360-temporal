import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/presentation/tracker_session_page.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_form_page.dart';
import 'package:fit_track_360/features/workouts/presentation/workouts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../settings/fakes.dart' show FakeConnectivityService;

class _FakeWorkoutsApi implements WorkoutsApi {
  @override
  Future<WorkoutSession> update(String id, Map<String, dynamic> payload) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  final created = <WorkoutSessionDraft>[];

  @override
  Future<List<WorkoutSession>> list() async => const [];

  @override
  Future<WorkoutSession> getById(String id) => throw UnimplementedError();

  @override
  Future<WorkoutSession> create(WorkoutSessionDraft draft) async {
    created.add(draft);
    return WorkoutSession(
      id: 'nueva',
      userId: 'u1',
      startedAt: draft.startedAt,
      endedAt: null,
      notes: draft.notes,
      createdAt: draft.startedAt,
      updatedAt: draft.startedAt,
    );
  }

  @override
  Future<WorkoutSession> createWithPayload(Map<String, dynamic> payload) async {
    final startedAt =
        DateTime.tryParse('${payload['startedAt']}') ??
        DateTime.utc(2026, 11, 10, 18);
    return WorkoutSession(
      id: 'nueva',
      userId: 'u1',
      startedAt: startedAt,
      endedAt: null,
      notes: payload['notes'] as String?,
      createdAt: startedAt,
      updatedAt: startedAt,
    );
  }
}

class _Storage implements SessionStorage {
  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      'access';

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _CountingApiClient extends ApiClient {
  _CountingApiClient(http.Client client)
    : super(storage: _Storage(), httpClient: client);

  int disposed = 0;

  @override
  void dispose() {
    disposed++;
    super.dispose();
  }
}

final _draft = WorkoutSessionDraft(
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

final _repeatedDraft = WorkoutSessionDraft(
  startedAt: DateTime.utc(2026, 11, 11, 19),
  exercises: const [
    PlannedExercise(
      exerciseId: 'ej-a',
      exerciseName: 'Sentadilla',
      position: 0,
      targetSets: 2,
      targetReps: 5,
    ),
    PlannedExercise(
      exerciseId: 'ej-b',
      exerciseName: 'Press banca',
      position: 1,
      targetSets: 1,
      targetReps: 10,
    ),
  ],
  sets: const [
    PlannedSet(exerciseId: 'ej-a', order: 1, weightKg: 100, reps: 5),
    PlannedSet(exerciseId: 'ej-a', order: 2, weightKg: 110, reps: 3),
    PlannedSet(exerciseId: 'ej-b', order: 3, weightKg: 60, reps: 10),
  ],
);

const _createdJson = {
  'id': 'nueva',
  'userId': 'u1',
  'routineId': 'rutina-1',
  'startedAt': '2026-11-10T18:00:00.000Z',
  'endedAt': null,
  'notes': 'Hecha desde la rutina',
  'createdAt': '2026-11-10T18:00:00.000Z',
  'updatedAt': '2026-11-10T18:00:00.000Z',
};

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

/// Abre [form] encima de una pantalla base y guarda lo que devuelve al cerrar.
Future<List<bool?>> _openForm(WidgetTester tester, Widget form) async {
  final results = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              results.add(
                await Navigator.of(context)
                    .push<bool>(MaterialPageRoute(builder: (_) => form)),
              );
            },
            child: const Text('Abrir formulario'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir formulario'));
  await tester.pumpAndSettle();
  return results;
}

Finder _formScrollable() => find
    .descendant(
      of: find.byKey(const Key('workout-form-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Registrar entrenamiento'),
    300,
    scrollable: _formScrollable(),
  );
  await tester.ensureVisible(find.text('Registrar entrenamiento'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Registrar entrenamiento'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el formulario muestra el borrador de la rutina', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutFormPage(api: _FakeWorkoutsApi(), draft: _draft),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rutina: Pierna'), findsOneWidget);
    expect(find.text('Sentadilla'), findsOneWidget);
    expect(find.text('4 series × 8 reps'), findsOneWidget);
  });

  testWidgets('sin nombre del ejercicio muestra su identificador', (
    tester,
  ) async {
    final draft = WorkoutSessionDraft(
      routineId: 'rutina-1',
      routineName: 'Pierna',
      startedAt: DateTime.utc(2026, 11, 10, 18),
      exercises: const [
        PlannedExercise(
          exerciseId: '0001',
          exerciseName: '',
          position: 1,
          targetSets: 3,
          targetReps: 10,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutFormPage(api: _FakeWorkoutsApi(), draft: draft),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ejercicio 0001'), findsOneWidget);
  });

  testWidgets('sin borrador la pestaña ofrece entrenar y registrar pasado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(
          api: _FakeWorkoutsApi(),
          connectivityService: FakeConnectivityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Rutina:'), findsNothing);
    expect(find.text('Entrenar ahora'), findsOneWidget);
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('Registrar entrenamiento'), findsNothing);
  });

  testWidgets('al registrar cierra el formulario una sola vez con true', (
    tester,
  ) async {
    final api = _FakeWorkoutsApi();
    final results = await _openForm(
      tester,
      WorkoutFormPage(api: api, draft: _draft),
    );

    await _tapSave(tester);

    expect(api.created.single.routineId, 'rutina-1');
    expect(results, [true]);
    expect(find.text('Rutina: Pierna'), findsNothing);
    expect(find.text('Abrir formulario'), findsOneWidget);
  });

  testWidgets('el POST lleva routineId, series y endedAt del registro', (
    tester,
  ) async {
    final posted = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posted.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _json(_createdJson, 201);
      }
      return _json(<Object>[], 200);
    });
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));

    await _openForm(tester, WorkoutFormPage(api: api, draft: _draft));
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Opcional'),
      300,
      scrollable: _formScrollable(),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Opcional'),
      'Hecha desde la rutina',
    );
    await _tapSave(tester);

    final body = posted.single;
    expect(body['routineId'], 'rutina-1');
    expect(body['startedAt'], '2026-11-10T18:00:00.000Z');
    expect(body['endedAt'], '2026-11-10T19:00:00.000Z');
    expect(body['notes'], 'Hecha desde la rutina');
    expect(body['sets'], [
      for (var order = 1; order <= 4; order++)
        {'exerciseId': 'ej-a', 'order': order, 'weight': 0, 'reps': 8},
    ]);
  });

  testWidgets('un borrador repetido envía sus series exactas sin routineId', (
    tester,
  ) async {
    final posted = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posted.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _json(_createdJson, 201);
      }
      return _json(<Object>[], 200);
    });
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));

    await _openForm(tester, WorkoutFormPage(api: api, draft: _repeatedDraft));
    await _tapSave(tester);

    final body = posted.single;
    expect(body.containsKey('routineId'), isFalse);
    expect(body['startedAt'], '2026-11-11T19:00:00.000Z');
    expect(body['sets'], [
      {'exerciseId': 'ej-a', 'order': 1, 'weight': 100, 'reps': 5},
      {'exerciseId': 'ej-a', 'order': 2, 'weight': 110, 'reps': 3},
      {'exerciseId': 'ej-b', 'order': 3, 'weight': 60, 'reps': 10},
    ]);
  });

  testWidgets('tras registrar, el historial muestra la sesión nueva', (
    tester,
  ) async {
    var created = false;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        created = true;
        return _json(_createdJson, 201);
      }
      return _json(created ? [_createdJson] : <Object>[], 200);
    });
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(
          api: api,
          connectivityService: FakeConnectivityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes sesiones'), findsOneWidget);

    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar entrenamiento pasado'), findsOneWidget);
    await _tapSave(tester);

    expect(find.text('Hecha desde la rutina'), findsOneWidget);
    expect(find.byType(WorkoutHistoryCard), findsOneWidget);
    expect(find.text('Entrenamiento registrado'), findsOneWidget);
  });

  testWidgets('un borrador recibido por la ruta abre el tracker', (
    tester,
  ) async {
    TrackerSessionArgs? received;
    final router = GoRouter(
      initialLocation: '/rutina',
      routes: [
        GoRoute(
          path: '/rutina',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  context.push('/app/entrenamientos', extra: _draft),
              child: const Text('Abrir sesión'),
            ),
          ),
        ),
        GoRoute(
          path: '/app/entrenamientos',
          builder: (context, state) => WorkoutsPage(
            connectivityService: FakeConnectivityService(),
            api: _FakeWorkoutsApi(),
            draft: state.extra as WorkoutSessionDraft?,
          ),
        ),
        GoRoute(
          path: workoutTrackerRoute,
          builder: (context, state) {
            received = state.extra as TrackerSessionArgs?;
            return const Scaffold(body: Text('Tracker'));
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Abrir sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Tracker'), findsOneWidget);
    expect(received?.draft?.routineId, 'rutina-1');
  });

  testWidgets('el formulario abierto con push muestra «Volver» y regresa', (
    tester,
  ) async {
    await _openForm(tester, WorkoutFormPage(api: _FakeWorkoutsApi()));

    expect(find.byTooltip('Volver'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Abrir formulario'), findsOneWidget);
  });

  testWidgets('como pantalla raíz no muestra «Volver»', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(
          api: _FakeWorkoutsApi(),
          connectivityService: FakeConnectivityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Volver'), findsNothing);
  });

  testWidgets('con API inyectada no crea un ApiClient propio', (tester) async {
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(
          connectivityService: FakeConnectivityService(),
          api: _FakeWorkoutsApi(),
          apiClientFactory: () {
            created++;
            return _CountingApiClient(
              MockClient((_) async => _json(<Object>[], 200)),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());

    expect(created, 0);
  });

  testWidgets('sin API inyectada crea un cliente y lo libera al salir', (
    tester,
  ) async {
    final clients = <_CountingApiClient>[];
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(
          connectivityService: FakeConnectivityService(),
          apiClientFactory: () {
            final client = _CountingApiClient(
              MockClient((_) async => _json(<Object>[], 200)),
            );
            clients.add(client);
            return client;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());

    expect(clients, hasLength(1));
    expect(clients.single.disposed, 1);
  });
}
