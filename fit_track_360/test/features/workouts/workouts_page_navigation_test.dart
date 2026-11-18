import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/presentation/workouts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_workouts_repository.dart';

void main() {
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
          builder: (context, state) => WorkoutsPage(api: api),
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
