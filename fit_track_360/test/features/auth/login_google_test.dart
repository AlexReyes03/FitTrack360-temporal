import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/auth/data/firebase_auth_service.dart';
import 'package:fit_track_360/features/auth/data/google_auth_gateway.dart';
import 'package:fit_track_360/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuth extends Fake implements FirebaseAuthService {
  Object? googleError;
  bool googleCalled = false;
  AuthUser? googleUser;

  @override
  Future<AuthUser> loginWithGoogle({
    bool allowAutoRegister = false,
    bool privacyConsent = false,
    String privacyNoticeVersion = '2',
  }) async {
    googleCalled = true;
    final error = googleError;
    if (error != null) {
      if (error is Exception) throw error;
      throw Exception(error.toString());
    }
    return googleUser ??
        const AuthUser(
          id: '1',
          email: 'a@test.com',
          username: 'ana',
          displayName: 'Ana',
          firebaseUid: 'uid-1',
        );
  }
}

Future<void> _pumpLogin(WidgetTester tester, {required _FakeAuth auth}) async {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(authService: auth),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const Text('REGISTER'),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const Text('FORGOT'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _tapGoogle(WidgetTester tester) async {
  final button = find.text('Continuar con Google');
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets('cancelar Google deja login sin banner de error', (tester) async {
    final auth = _FakeAuth()
      ..googleError = const GoogleSignInCancelledException();

    await _pumpLogin(tester, auth: auth);
    await _tapGoogle(tester);
    await tester.pumpAndSettle();

    expect(auth.googleCalled, isTrue);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.textContaining('No se pudo'), findsNothing);
    expect(find.textContaining('cuenta vinculada'), findsNothing);
  });

  testWidgets('error controlado de Google se muestra en el banner', (
    tester,
  ) async {
    final auth = _FakeAuth()
      ..googleError = const AuthApiException(
        'El correo ya esta registrado con otra cuenta',
      );

    await _pumpLogin(tester, auth: auth);
    await _tapGoogle(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('El correo ya esta registrado con otra cuenta'),
      findsOneWidget,
    );
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('Google exitoso navega a /app', (tester) async {
    final auth = _FakeAuth();
    await _pumpLogin(tester, auth: auth);
    await _tapGoogle(tester);
    await tester.pumpAndSettle();

    expect(auth.googleCalled, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });
}
