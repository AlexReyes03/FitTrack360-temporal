import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/presentation/workouts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeWorkoutsApi implements WorkoutsApi {
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

void main() {
  testWidgets('la pantalla de sesión muestra el borrador de la rutina', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(api: _FakeWorkoutsApi(), draft: _draft),
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
        home: WorkoutsPage(api: _FakeWorkoutsApi(), draft: draft),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ejercicio 0001'), findsOneWidget);
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

  testWidgets('tras crear, el borrador desaparece y no se reenvía', (
    tester,
  ) async {
    final api = _FakeWorkoutsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(api: api, draft: _draft),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear sesión'));
    await tester.pumpAndSettle();

    expect(api.created.single.routineId, 'rutina-1');
    expect(find.text('Rutina: Pierna'), findsNothing);
    expect(find.text('Sentadilla'), findsNothing);
    expect(find.text('Sesión guardada'), findsOneWidget);

    await tester.tap(find.text('Crear sesión'));
    await tester.pumpAndSettle();

    expect(api.created, hasLength(2));
    expect(api.created.last.routineId, isNull);
    expect(api.created.last.exercises, isEmpty);
  });

  testWidgets('el POST lleva routineId y series del borrador al API', (
    tester,
  ) async {
    final posted = <Map<String, dynamic>>[];
    var created = false;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posted.add(jsonDecode(request.body) as Map<String, dynamic>);
        created = true;
        return _json(_createdJson, 201);
      }
      return _json(created ? [_createdJson] : <Object>[], 200);
    });
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(api: api, draft: _draft),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hecha desde la rutina');
    await tester.tap(find.text('Crear sesión'));
    await tester.pumpAndSettle();

    final body = posted.single;
    expect(body['routineId'], 'rutina-1');
    expect(body['startedAt'], '2026-11-10T18:00:00.000Z');
    expect(body['notes'], 'Hecha desde la rutina');
    expect(body['sets'], [
      for (var order = 1; order <= 4; order++)
        {'exerciseId': 'ej-a', 'order': order, 'weight': 0, 'reps': 8},
    ]);
    expect(find.text('Rutina: Pierna'), findsNothing);
    expect(find.text('Hecha desde la rutina'), findsOneWidget);
  });

  testWidgets('abierta con push muestra «Volver» y regresa', (tester) async {
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
            api: _FakeWorkoutsApi(),
            draft: state.extra as WorkoutSessionDraft?,
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Abrir sesión'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Volver'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Abrir sesión'), findsOneWidget);
    expect(find.text('Rutina: Pierna'), findsNothing);
  });

  testWidgets('como pantalla raíz no muestra «Volver»', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WorkoutsPage(api: _FakeWorkoutsApi())),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Volver'), findsNothing);
  });

  testWidgets('con API inyectada no crea un ApiClient propio', (tester) async {
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsPage(
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
