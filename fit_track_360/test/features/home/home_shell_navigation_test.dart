import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/home/presentation/home_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _OnlineConnectivity implements ConnectivityService {
  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => true;
}

class _Storage implements SessionStorage {
  String? accessToken = 'access';

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {
    accessToken = null;
  }
}

http.Response _profile() => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'id': '1',
      'email': 'ana@test.com',
      'username': 'ana',
      'displayName': 'Ana',
      'createdAt': '2026-11-04T00:00:00.000Z',
    }),
  ),
  200,
);

http.Response _dashboardEmpty() => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'date': '2026-11-19',
      'utcOffsetMinutes': -360,
      'nutrition': {
        'mealsLogged': 0,
        'consumed': {'calories': 0, 'proteinG': 0, 'carbsG': 0, 'fatG': 0},
        'goals': {
          'dailyCalorieGoal': 2000,
          'proteinGoalG': 150,
          'carbsGoalG': 200,
          'fatGoalG': 60,
        },
        'remaining': {
          'calories': 2000,
          'proteinG': 150,
          'carbsG': 200,
          'fatG': 60,
        },
      },
      'session': null,
      'latestMetric': null,
    }),
  ),
  200,
  headers: {'content-type': 'application/json'},
);

Future<http.Response> _route(http.Request request) async {
  final path = request.url.path;
  if (path.endsWith('/users/me')) return _profile();
  if (path.contains('/dashboard/today')) return _dashboardEmpty();
  return http.Response('not found', 404);
}

void main() {
  testWidgets('bottom nav y accesos rapidos llegan a las rutas principales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final storage = _Storage();
    final visited = <String>[];
    final router = GoRouter(
      initialLocation: '/app',
      routes: [
        GoRoute(
          path: '/app',
          builder: (context, state) => HomeShellPage(
            apiClient: ApiClient(
              storage: storage,
              httpClient: MockClient(_route),
            ),
            sessionStorage: storage,
            connectivityService: _OnlineConnectivity(),
          ),
        ),
        GoRoute(
          path: '/app/entrenamientos',
          builder: (context, state) {
            visited.add('entrenamientos');
            return const Text('vista-entrenamientos');
          },
        ),
        GoRoute(
          path: '/app/comidas',
          builder: (context, state) {
            visited.add('comidas');
            return const Text('vista-comidas');
          },
        ),
        GoRoute(
          path: '/app/ejercicios',
          builder: (context, state) {
            visited.add('ejercicios');
            return const Text('vista-ejercicios');
          },
        ),
        GoRoute(
          path: '/app/foto',
          builder: (context, state) {
            visited.add('foto');
            return const Text('vista-foto');
          },
        ),
        GoRoute(
          path: '/app/progreso',
          builder: (context, state) {
            visited.add('progreso');
            return const Text('vista-progreso');
          },
        ),
        GoRoute(
          path: '/app/perfil',
          builder: (context, state) {
            visited.add('perfil');
            return const Text('vista-perfil');
          },
        ),
        GoRoute(
          path: '/app/tracker',
          builder: (context, state) {
            visited.add('tracker');
            return const Text('vista-tracker');
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    Future<void> openAndBack(Finder tapTarget, String marker) async {
      await tester.ensureVisible(tapTarget);
      await tester.tap(tapTarget);
      await tester.pumpAndSettle();
      expect(find.text(marker), findsOneWidget);
      router.go('/app');
      await tester.pumpAndSettle();
    }

    await openAndBack(find.text('Entrenos'), 'vista-entrenamientos');
    await openAndBack(find.text('Comidas').first, 'vista-comidas');
    await openAndBack(find.text('Ejercicios'), 'vista-ejercicios');
    await openAndBack(find.text('Progreso'), 'vista-progreso');
    await openAndBack(find.text('Perfil').last, 'vista-perfil');
    await openAndBack(find.text('Tracker diario'), 'vista-tracker');

    expect(
      visited,
      containsAll([
        'entrenamientos',
        'comidas',
        'ejercicios',
        'progreso',
        'perfil',
        'tracker',
      ]),
    );
  });
}
