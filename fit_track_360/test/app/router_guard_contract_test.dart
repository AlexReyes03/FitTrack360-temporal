import 'package:fit_track_360/app/router.dart';
import 'package:fit_track_360/core/session_storage.dart';
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

GoRouter _router(SessionStorage storage) {
  final previous = appSessionStorage;
  appSessionStorage = storage;
  addTearDown(() => appSessionStorage = previous);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) => resolveAppSessionRedirect(state),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const Text('login')),
      GoRoute(path: '/app', builder: (context, state) => const Text('app')),
      GoRoute(
        path: appTrackerPath,
        builder: (context, state) => const Text('tracker'),
      ),
      GoRoute(
        path: appFoodSearchPath,
        builder: (context, state) => const Text('buscar'),
      ),
      GoRoute(
        path: '/app/perfil',
        builder: (context, state) => const Text('perfil'),
      ),
    ],
  );
}

void main() {
  testWidgets('sin sesion, rutas privadas /app* redirigen a login', (
    tester,
  ) async {
    final router = _router(_TokenStorage(null));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    for (final path in [
      '/app',
      '/app/perfil',
      appTrackerPath,
      appFoodSearchPath,
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.text('login'), findsOneWidget, reason: path);
    }
  });

  testWidgets('con sesion no se queda en /login', (tester) async {
    final router = _router(_TokenStorage('token'));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('app'), findsOneWidget);
    expect(find.text('login'), findsNothing);
  });
}
