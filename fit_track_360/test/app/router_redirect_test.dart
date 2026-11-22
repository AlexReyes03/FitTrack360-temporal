import 'package:fit_track_360/core/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Misma politica que `appRouter.redirect` en `lib/app/router.dart`:
/// sin sesion no se entra a `/app*`; con sesion no se queda en auth.
const _authRoutes = {'/login', '/register', '/forgot-password'};

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
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final accessToken = await storage.readAccessToken();
      final location = state.matchedLocation;
      final hasSession = accessToken != null;

      if (!hasSession && location.startsWith('/app')) return '/login';
      if (hasSession && _authRoutes.contains(location)) return '/app';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const Text('login')),
      GoRoute(path: '/app', builder: (context, state) => const Text('app')),
      GoRoute(
        path: '/app/perfil',
        builder: (context, state) => const Text('perfil'),
      ),
    ],
  );
}

void main() {
  testWidgets('ruta privada sin sesion redirige a login', (tester) async {
    final storage = _TokenStorage(null);
    final router = _router(storage);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/app/perfil');
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(find.text('perfil'), findsNothing);
  });

  testWidgets('con sesion no se queda en login', (tester) async {
    final storage = _TokenStorage('token');
    final router = _router(storage);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('app'), findsOneWidget);
    expect(find.text('login'), findsNothing);
  });
}
