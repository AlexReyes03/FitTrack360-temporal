import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/features/home/presentation/app_shell_page.dart';
import 'package:fit_track_360/features/home/presentation/home_shell_page.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_scope.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/exercise_test_support.dart';

class FakeConnectivityService implements ConnectivityService {
  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => true;
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

void main() {
  testWidgets('Home abre el catálogo de ejercicios desde el shell', (
    tester,
  ) async {
    final storage = FakeSessionStorage();
    final notifications = NotificationsViewModel(initialNotifications: []);
    addTearDown(notifications.dispose);
    final router = GoRouter(
      initialLocation: '/app',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShellPage(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app',
                  builder: (context, state) => HomeShellPage(
                    apiClient: ApiClient(
                      storage: storage,
                      httpClient: MockClient((request) async {
                        if (request.url.path.endsWith('/users/me')) {
                          return _profile();
                        }
                        if (request.url.path.contains('/dashboard/today')) {
                          return _dashboardEmpty();
                        }
                        return http.Response('not found', 404);
                      }),
                    ),
                    sessionStorage: storage,
                    connectivityService: FakeConnectivityService(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app/entrenamientos',
                  builder: (context, state) =>
                      const Text('vista-entrenamientos'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app/comidas',
                  builder: (context, state) => const Text('vista-comidas'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app/ejercicios',
                  builder: (context, state) =>
                      const Text('Catálogo de ejercicios'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app/progreso',
                  builder: (context, state) => const Text('vista-progreso'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/app/perfil',
                  builder: (context, state) => const Text('vista-perfil'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      NotificationsScope(
        notifier: notifications,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ejercicios'), findsOneWidget);

    await tester.tap(find.text('Ejercicios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Catálogo de ejercicios'), findsOneWidget);
  });
}
