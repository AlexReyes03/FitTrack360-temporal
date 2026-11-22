import 'package:fit_track_360/app/router.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_page.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_scope.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TokenStorage implements SessionStorage {
  _TokenStorage(this.accessToken);

  String? accessToken;

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

Iterable<String> _flattenPaths(
  Iterable<RouteBase> routes, [
  String parentPath = '',
]) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      final path = route.path.startsWith('/')
          ? route.path
          : '$parentPath/${route.path}';
      yield path;
      yield* _flattenPaths(route.routes, path);
    } else if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        yield* _flattenPaths(branch.routes);
      }
    } else if (route is ShellRoute) {
      yield* _flattenPaths(route.routes);
    }
  }
}

void main() {
  test('las 6 vistas principales viven en ramas del shell persistente', () {
    final routes = buildAppRoutes();
    final shell = routes.whereType<StatefulShellRoute>().single;

    expect(shell.branches, hasLength(6));
    final branchRoots = shell.branches
        .map((branch) => (branch.routes.single as GoRoute).path)
        .toList();

    expect(branchRoots, [
      '/app',
      '/app/entrenamientos',
      '/app/comidas',
      '/app/ejercicios',
      '/app/progreso',
      '/app/perfil',
    ]);
  });

  test('las rutas secundarias y notificaciones conservan su path', () {
    final paths = _flattenPaths(buildAppRoutes()).toSet();

    expect(
      paths,
      containsAll([
        '/app/entrenamientos/:id',
        '/app/ejercicios/:id',
        '/app/progreso/comparar',
        appNotificationsPath,
        '/app/foto',
        appTrackerPath,
        appFoodSearchPath,
        '/app/rutinas',
        '/app/rutinas/:id',
      ]),
    );
  });

  test(
    'notificaciones queda fuera del shell para abrirse a pantalla completa',
    () {
      final routes = buildAppRoutes();
      final shell = routes.whereType<StatefulShellRoute>().single;
      final shellPaths = _flattenPaths(shell.branches.expand((b) => b.routes))
          .toSet();

      expect(shellPaths, isNot(contains(appNotificationsPath)));
      expect(
        routes.whereType<GoRoute>().map((r) => r.path),
        contains(appNotificationsPath),
      );
    },
  );

  testWidgets('la ruta /app/notificaciones usa el ViewModel compartido', (
    tester,
  ) async {
    final previousStorage = appSessionStorage;
    appSessionStorage = _TokenStorage('token');
    addTearDown(() => appSessionStorage = previousStorage);

    final notifications = NotificationsViewModel(
      initialNotifications: [
        AppNotification(
          id: 'login',
          title: 'Nuevo inicio de sesión',
          message: 'Se inició sesión en otro dispositivo.',
          type: AppNotificationType.newLogin,
          createdAt: DateTime(2026, 11, 22, 10),
        ),
      ],
    );
    addTearDown(notifications.dispose);

    final router = GoRouter(
      initialLocation: appNotificationsPath,
      redirect: (context, state) => resolveAppSessionRedirect(state),
      routes: buildAppRoutes(),
    );

    await tester.pumpWidget(
      NotificationsScope(
        notifier: notifications,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
  });
}
