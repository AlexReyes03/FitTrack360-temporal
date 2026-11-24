import 'package:fit_track_360/design_system/templates/form_page_template.dart';
import 'package:fit_track_360/features/auth/domain/auth_messages.dart';
import 'package:fit_track_360/features/auth/presentation/forgot_password_page.dart';
import 'package:fit_track_360/features/auth/presentation/widgets/auth_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_auth_service.dart';

Future<void> _pumpForgot(
  WidgetTester tester,
  FakeAuthService auth, {
  String? initialEmail,
}) async {
  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) =>
            ForgotPasswordPage(authService: auth, initialEmail: initialEmail),
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

Future<void> _tapSubmit(WidgetTester tester) async {
  final cta = find.text(AuthMessages.recoverySubmit);
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('usa FormPageTemplate, AuthHeader y precarga el correo', (
    tester,
  ) async {
    await _pumpForgot(tester, FakeAuthService(), initialEmail: 'ana@test.com');

    expect(find.byType(FormPageTemplate), findsOneWidget);
    expect(find.byType(AuthHeader), findsOneWidget);
    expect(find.text(AuthMessages.recoveryTitle), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ana@test.com',
    );
  });

  testWidgets('confirmación genérica anunciada y visible', (tester) async {
    final auth = FakeAuthService();
    await _pumpForgot(tester, auth, initialEmail: 'ana@test.com');
    await _tapSubmit(tester);

    expect(auth.lastEmail, 'ana@test.com');
    expect(find.text(AuthMessages.recoverySuccess), findsOneWidget);
    expect(liveRegionWithText(AuthMessages.recoverySuccess), findsOneWidget);
    expectFullyOnScreen(tester, find.text(AuthMessages.recoverySuccess));
  });

  testWidgets('correo vacío explica qué falta', (tester) async {
    final auth = FakeAuthService();
    await _pumpForgot(tester, auth);
    await _tapSubmit(tester);

    expect(find.text(AuthMessages.recoveryRequiredEmail), findsOneWidget);
    expect(auth.resetCalls, 0);
  });

  testWidgets('fallo técnico muestra el genérico, no el texto del error', (
    tester,
  ) async {
    final auth = FakeAuthService()..resetError = StateError('boom');
    await _pumpForgot(tester, auth, initialEmail: 'ana@test.com');
    await _tapSubmit(tester);

    expect(find.text(AuthMessages.recoveryGeneric), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('«Volver a iniciar sesión» sin pila previa usa go(/login)', (
    tester,
  ) async {
    await _pumpForgot(tester, FakeAuthService());
    final link = find.text(AuthMessages.backToLogin);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
