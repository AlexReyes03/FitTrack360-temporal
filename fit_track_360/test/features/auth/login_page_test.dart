import 'dart:async';

import 'package:fit_track_360/design_system/templates/form_page_template.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/auth/domain/auth_messages.dart';
import 'package:fit_track_360/features/auth/presentation/login_page.dart';
import 'package:fit_track_360/features/auth/presentation/widgets/auth_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_auth_service.dart';

Future<GoRouter> _pumpLogin(WidgetTester tester, FakeAuthService auth) async {
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
        builder: (context, state) => const Scaffold(body: Text('REGISTER')),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) =>
            Scaffold(body: Text('FORGOT:${state.extra}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _fill(WidgetTester tester, String email, String password) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final cta = find.text(AuthMessages.loginSubmit);
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
}

void main() {
  testWidgets('usa FormPageTemplate, AuthHeader y copy con acentos', (
    tester,
  ) async {
    await _pumpLogin(tester, FakeAuthService());

    expect(find.byType(FormPageTemplate), findsOneWidget);
    expect(find.byType(AuthHeader), findsOneWidget);
    expect(find.text(AuthMessages.loginTitle), findsOneWidget);
    expect(find.text(AuthMessages.emailLabel), findsOneWidget);
    expect(find.text(AuthMessages.loginSubmit), findsOneWidget);
    expect(find.text(AuthMessages.forgotPasswordLink), findsOneWidget);
    expect(find.text(AuthMessages.registerLink), findsOneWidget);
    // El hint de longitud solo aplica al crear la contraseña.
    expect(find.text(AuthMessages.passwordHint), findsNothing);
    expect(find.text('Iniciar sesion'), findsNothing);
  });

  testWidgets('muestra indicador de carga en el CTA mientras envía', (
    tester,
  ) async {
    final auth = FakeAuthService()..gate = Completer<void>();
    await _pumpLogin(tester, auth);
    await _fill(tester, 'ana@test.com', 'Password1');
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text(AuthMessages.loginSubmitting), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text(AuthMessages.loginSubmitting));
    await tester.pump();
    expect(auth.loginCalls, 1);

    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets(
    'error del backend («Token invalido») se traduce, se anuncia y queda '
    'justo bajo el CTA y visible',
    (tester) async {
      final auth = FakeAuthService()
        ..loginError = const AuthApiException(
          'Token invalido',
          statusCode: 401,
        );
      await _pumpLogin(tester, auth);
      await _fill(tester, 'ana@test.com', 'Password1');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Token invalido'), findsNothing);
      final banner = find.text(AuthMessages.sessionInvalid);
      expect(banner, findsOneWidget);
      expect(liveRegionWithText(AuthMessages.sessionInvalid), findsOneWidget);
      expectFullyOnScreen(tester, banner);

      final ctaBottom = tester
          .getRect(find.text(AuthMessages.loginSubmit))
          .bottom;
      final googleTop = tester.getRect(find.text('Continuar con Google')).top;
      final bannerRect = tester.getRect(banner);
      expect(bannerRect.top, greaterThan(ctaBottom));
      expect(bannerRect.bottom, lessThan(googleTop));
    },
  );

  testWidgets('valida al tocar y explica por qué no avanza', (tester) async {
    final auth = FakeAuthService();
    await _pumpLogin(tester, auth);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text(AuthMessages.requiredFields), findsOneWidget);
    expect(auth.loginCalls, 0);
  });

  testWidgets('la contraseña se envía sin recortar', (tester) async {
    final auth = FakeAuthService();
    await _pumpLogin(tester, auth);
    await _fill(tester, '  ana@test.com ', ' Password1 ');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(auth.lastEmail, 'ana@test.com');
    expect(auth.lastPassword, ' Password1 ');
  });

  testWidgets('«¿Olvidaste tu contraseña?» pasa el correo escrito', (
    tester,
  ) async {
    await _pumpLogin(tester, FakeAuthService());
    await tester.enterText(find.byType(TextField).first, ' ana@test.com ');
    final link = find.text(AuthMessages.forgotPasswordLink);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.text('FORGOT:ana@test.com'), findsOneWidget);
  });
}
