import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/auth/presentation/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TokenStorage implements SessionStorage {
  _TokenStorage(this.accessToken);

  final String? accessToken;

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
  Future<void> clear() async {}
}

Future<void> _pumpSplash(WidgetTester tester, String? token) async {
  final previous = appSessionStorage;
  appSessionStorage = _TokenStorage(token);
  addTearDown(() => appSessionStorage = previous);

  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('LOGIN')),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('sin sesión va directo a login, sin espera ni botón', (
    tester,
  ) async {
    await _pumpSplash(tester, null);
    expect(find.text('Ingresar'), findsNothing);

    // Sin la espera fija de 700 ms: basta con resolver el almacenamiento.
    await tester.pump();
    await tester.pump();
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('con sesión va a /app', (tester) async {
    await _pumpSplash(tester, 'token');
    await tester.pump();
    await tester.pump();
    expect(find.text('HOME'), findsOneWidget);
  });
}
