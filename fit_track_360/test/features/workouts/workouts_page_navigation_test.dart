import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/presentation/workouts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../settings/fakes.dart' show FakeConnectivityService;
import 'fake_workouts_repository.dart';

WorkoutsApi _api(List<Object> sessions, {List<String>? requests}) {
  final client = MockClient((request) async {
    requests?.add('${request.method} ${request.url.path}');
    return http.Response.bytes(utf8.encode(jsonEncode(sessions)), 200);
  });
  return WorkoutsApi(
    ApiClient(storage: FakeSessionStorage(), httpClient: client),
  );
}

const _session = {
  'id': 'abc',
  'userId': 'u1',
  'startedAt': '2026-11-04T10:00:00.000Z',
  'endedAt': '2026-11-04T10:45:00.000Z',
  'notes': 'Pierna',
  'createdAt': '2026-11-04T10:00:00.000Z',
  'updatedAt': '2026-11-04T10:00:00.000Z',
  'sets': [
    {'exerciseId': 'e1', 'exerciseName': 'Sentadilla', 'order': 1, 'reps': 8},
    {'exerciseId': 'e1', 'exerciseName': 'Sentadilla', 'order': 2, 'reps': 8},
  ],
};

GoRouter _router(WorkoutsApi api) => GoRouter(
  initialLocation: '/app/entrenamientos',
  routes: [
    GoRoute(
      path: '/app/entrenamientos',
      builder: (context, state) => WorkoutsPage(
        api: api,
        connectivityService: FakeConnectivityService(),
      ),
    ),
    GoRoute(
      path: '/app/entrenamientos/:id',
      builder: (context, state) =>
          Scaffold(body: Text('Detalle ${state.pathParameters['id']}')),
    ),
    GoRoute(
      path: '/app/tracker',
      builder: (context, state) => const Scaffold(body: Text('Tracker')),
    ),
    GoRoute(
      path: '/app/rutinas',
      builder: (context, state) => const Scaffold(body: Text('Rutinas lista')),
    ),
  ],
);

void main() {
  testWidgets('el historial usa tarjetas con duración y resumen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(_api([_session]))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutHistoryCard), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('1 ejercicio · 2 series'), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
  });

  testWidgets('el encabezado abre Rutinas', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(_api(const []))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rutinas'));
    await tester.pumpAndSettle();

    expect(find.text('Rutinas lista'), findsOneWidget);
  });

  testWidgets('«Entrenar ahora» abre el tracker y al volver recarga', (
    tester,
  ) async {
    final requests = <String>[];
    final router = _router(_api(const [], requests: requests));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));

    await tester.tap(find.text('Entrenar ahora'));
    await tester.pumpAndSettle();
    expect(find.text('Tracker'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
  });

  testWidgets('tocar una sesión de la lista abre su detalle', (tester) async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode([
            {
              'id': 'abc',
              'userId': 'u1',
              'startedAt': '2026-11-04T10:00:00.000Z',
              'endedAt': null,
              'notes': 'Pierna',
              'createdAt': '2026-11-04T10:00:00.000Z',
              'updatedAt': '2026-11-04T10:00:00.000Z',
            },
          ]),
        ),
        200,
      ),
    );
    final api = WorkoutsApi(
      ApiClient(storage: FakeSessionStorage(), httpClient: client),
    );
    final router = GoRouter(
      initialLocation: '/app/entrenamientos',
      routes: [
        GoRoute(
          path: '/app/entrenamientos',
          builder: (context, state) => WorkoutsPage(
            api: api,
            connectivityService: FakeConnectivityService(),
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pierna'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle abc'), findsOneWidget);
  });
}
