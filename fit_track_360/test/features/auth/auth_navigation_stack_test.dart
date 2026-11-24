import 'package:fit_track_360/features/auth/domain/auth_messages.dart';
import 'package:fit_track_360/features/auth/presentation/forgot_password_page.dart';
import 'package:fit_track_360/features/auth/presentation/login_page.dart';
import 'package:fit_track_360/features/auth/presentation/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_auth_service.dart';

/// Regresión: «Volver a iniciar sesión» hacía `push('/login')` y la pila
/// crecía (login → registro → login…).
Future<GoRouter> _pumpAuthFlow(WidgetTester tester) async {
  final auth = FakeAuthService();
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(authService: auth),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterPage(authService: auth),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordPage(
          authService: auth,
          initialEmail: state.extra is String ? state.extra as String : null,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login → registro → «Inicia sesión» regresa sin apilar', (
    tester,
  ) async {
    final router = await _pumpAuthFlow(tester);

    for (var i = 0; i < 3; i++) {
      await _tap(tester, AuthMessages.registerLink);
      expect(find.byType(RegisterPage), findsOneWidget);
      await _tap(tester, AuthMessages.loginLink);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(router.canPop(), isFalse, reason: 'vuelta $i');
    }
  });

  testWidgets('login → recuperar → volver regresa sin apilar', (tester) async {
    final router = await _pumpAuthFlow(tester);

    await _tap(tester, AuthMessages.forgotPasswordLink);
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    await _tap(tester, AuthMessages.backToLogin);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ForgotPasswordPage), findsNothing);
    expect(router.canPop(), isFalse);
  });
}
