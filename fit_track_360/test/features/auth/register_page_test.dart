import 'dart:async';

import 'package:fit_track_360/design_system/templates/form_page_template.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/auth/domain/auth_messages.dart';
import 'package:fit_track_360/features/auth/presentation/register_page.dart';
import 'package:fit_track_360/features/auth/presentation/widgets/auth_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_auth_service.dart';

Future<void> _pumpRegister(WidgetTester tester, FakeAuthService auth) async {
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterPage(authService: auth),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/aviso-privacidad',
        builder: (context, state) => const Scaffold(body: Text('AVISO')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _fillAll(
  WidgetTester tester, {
  String password = 'Password1',
  String? confirm,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Ana');
  await tester.enterText(fields.at(1), 'ana_01');
  await tester.enterText(fields.at(2), 'ana@test.com');
  await tester.enterText(fields.at(3), password);
  await tester.enterText(fields.at(4), confirm ?? password);
}

Finder get _consentCheckbox => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.checked != null,
);

Future<void> _acceptConsent(WidgetTester tester) async {
  await tester.ensureVisible(_consentCheckbox);
  await tester.pumpAndSettle();
  await tester.tap(_consentCheckbox);
  await tester.pumpAndSettle();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final cta = find.text(AuthMessages.registerSubmit);
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
}

void main() {
  testWidgets('usa FormPageTemplate, AuthHeader y copy con acentos', (
    tester,
  ) async {
    await _pumpRegister(tester, FakeAuthService());

    expect(find.byType(FormPageTemplate), findsOneWidget);
    expect(find.byType(AuthHeader), findsOneWidget);
    expect(find.text(AuthMessages.registerTitle), findsOneWidget);
    expect(find.text(AuthMessages.privacyConsentLabel), findsOneWidget);
    expect(find.text(AuthMessages.loginPrompt), findsOneWidget);
  });

  testWidgets('checkbox de consentimiento expone checked y mide 48dp', (
    tester,
  ) async {
    await _pumpRegister(tester, FakeAuthService());

    expect(_consentCheckbox, findsOneWidget);
    expect(
      tester.widget<Semantics>(_consentCheckbox).properties.checked,
      isFalse,
    );
    expect(tester.getSize(_consentCheckbox).height, greaterThanOrEqualTo(48));

    await _acceptConsent(tester);
    expect(
      tester.widget<Semantics>(_consentCheckbox).properties.checked,
      isTrue,
    );
  });

  testWidgets('«Consultar aviso de privacidad» abre el aviso', (tester) async {
    await _pumpRegister(tester, FakeAuthService());

    final link = find.text(AuthMessages.privacyNoticeLink);
    expect(link, findsOneWidget);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.text('AVISO'), findsOneWidget);
  });

  testWidgets('CTA vacío no es un botón muerto: explica qué falta', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await _pumpRegister(tester, auth);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text(AuthMessages.requiredFields), findsOneWidget);
    expect(find.text(AuthMessages.requiredField), findsNWidgets(5));
    expectFullyOnScreen(tester, find.text(AuthMessages.requiredFields));
    expect(auth.registerCalls, 0);
  });

  testWidgets('sin consentimiento explica por qué no avanza', (tester) async {
    final auth = FakeAuthService();
    await _pumpRegister(tester, auth);
    await _fillAll(tester);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text(AuthMessages.consentRequired), findsOneWidget);
    expect(liveRegionWithText(AuthMessages.consentRequired), findsOneWidget);
    expect(auth.registerCalls, 0);

    // Al aceptar el aviso el motivo desaparece y el registro avanza.
    await _acceptConsent(tester);
    expect(find.text(AuthMessages.consentRequired), findsNothing);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets(
    'error de backend queda bajo el CTA (encima de Google), visible y '
    'anunciado',
    (tester) async {
      final auth = FakeAuthService()
        ..registerError = const AuthApiException(
          'El usuario ya esta registrado',
          statusCode: 409,
        );
      await _pumpRegister(tester, auth);
      await _fillAll(tester);
      await _acceptConsent(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      final banner = find.text(AuthMessages.usernameAlreadyRegistered);
      expect(banner, findsOneWidget);
      expect(
        liveRegionWithText(AuthMessages.usernameAlreadyRegistered),
        findsOneWidget,
      );
      expectFullyOnScreen(tester, banner);
      final ctaBottom = tester
          .getRect(find.text(AuthMessages.registerSubmit))
          .bottom;
      final googleTop = tester.getRect(find.text('Continuar con Google')).top;
      expect(tester.getRect(banner).top, greaterThan(ctaBottom));
      expect(tester.getRect(banner).bottom, lessThan(googleTop));
    },
  );

  testWidgets('«Internal server error» nunca llega a la UI', (tester) async {
    final auth = FakeAuthService()
      ..registerError = const AuthApiException(
        'Internal server error',
        statusCode: 500,
      );
    await _pumpRegister(tester, auth);
    await _fillAll(tester);
    await _acceptConsent(tester);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Internal server error'), findsNothing);
    expect(find.text(AuthMessages.registerGeneric), findsOneWidget);
  });

  testWidgets('indicador de carga en «Crear cuenta» mientras envía', (
    tester,
  ) async {
    final auth = FakeAuthService()..gate = Completer<void>();
    await _pumpRegister(tester, auth);
    await _fillAll(tester);
    await _acceptConsent(tester);
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text(AuthMessages.registerSubmitting), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(auth.registerCalls, 1);
  });

  testWidgets('la contraseña no se recorta (igual que en login)', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await _pumpRegister(tester, auth);
    await _fillAll(tester, password: ' Password1 ');
    await _acceptConsent(tester);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(auth.lastPassword, ' Password1 ');
  });

  testWidgets('«Inicia sesión» sin pila previa usa go(/login)', (tester) async {
    await _pumpRegister(tester, FakeAuthService());
    final link = find.text(AuthMessages.loginLink);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
