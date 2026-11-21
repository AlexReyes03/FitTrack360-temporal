import 'dart:async';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/settings/domain/privacy_notice.dart';
import 'package:fit_track_360/features/settings/domain/privacy_repository.dart';
import 'package:fit_track_360/features/settings/presentation/privacy_notice_page.dart';
import 'package:fit_track_360/features/settings/presentation/privacy_notice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakePrivacyRepository repository, {
  String userId = 'u1',
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PrivacyNoticePage(userId: userId, repository: repository),
    ),
  );
}

Future<void> _accept(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('privacy-consent-checkbox')));
  await tester.pump();
  await tester.tap(find.text('Aceptar aviso'));
  await tester.pump();
}

void main() {
  group('estados remotos', () {
    testWidgets('loading y luego versión, fecha, secciones y salud', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repo = FakePrivacyRepository()..noticeGate = gate.future;
      await _pump(tester, repo);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Versión 2 · 16 de noviembre de 2026'), findsOneWidget);
      expect(find.text('Cuenta'), findsOneWidget);
      expect(find.text('Salud'), findsOneWidget);
      expect(find.textContaining('atención médica'), findsOneWidget);
      expect(find.byKey(const Key('privacy-medical-missing')), findsNothing);
    });

    testWidgets('error con reintento', (tester) async {
      final repo = FakePrivacyRepository()..noticeError = Exception('500');
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text(privacyUnavailableMessage), findsOneWidget);

      repo.noticeError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Versión 2'), findsOneWidget);
      expect(repo.noticeCalls, 2);
    });

    testWidgets('sesión expirada se informa al cargar', (tester) async {
      final repo = FakePrivacyRepository()
        ..noticeError = const SessionExpiredException();
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text(privacySessionExpiredMessage), findsOneWidget);
    });

    testWidgets('aviso sin secciones queda en vacío con reintento', (
      tester,
    ) async {
      final repo = FakePrivacyRepository(
        notice: PrivacyNotice(
          version: '2',
          date: DateTime(2026, 11, 16),
          sections: const [],
        ),
      );
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(
        find.text('El aviso no tiene secciones para mostrar.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('aviso sin sección de salud lo advierte', (tester) async {
      final repo = FakePrivacyRepository(
        notice: PrivacyNotice(
          version: '2',
          date: DateTime(2026, 11, 16),
          sections: const [
            PrivacyNoticeSection(title: 'Cuenta', text: 'Datos de la cuenta.'),
          ],
        ),
      );
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Cuenta'), findsOneWidget);
      expect(find.text('Datos de la cuenta.'), findsOneWidget);
      expect(
        find.text('El aviso recibido no incluye una sección de salud.'),
        findsOneWidget,
      );
    });
  });

  group('consentimiento', () {
    testWidgets('sin marcar la casilla no envía el consentimiento', (
      tester,
    ) async {
      final repo = FakePrivacyRepository();
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aceptar aviso'));
      await tester.pumpAndSettle();

      expect(repo.consents, isEmpty);
      expect(
        find.byKey(const Key('privacy-consent-confirmation')),
        findsNothing,
      );
    });

    testWidgets('confirmación solo después de la respuesta del servidor', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repo = FakePrivacyRepository()..consentGate = gate.future;
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await _accept(tester);

      expect(find.text('Registrando...'), findsOneWidget);
      expect(
        find.byKey(const Key('privacy-consent-confirmation')),
        findsNothing,
      );

      gate.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('Consentimiento registrado para la versión 2.'),
        findsOneWidget,
      );
      expect(repo.consents.single, (userId: 'u1', version: '2'));
    });

    testWidgets('un rechazo muestra error y no confirma', (tester) async {
      final repo = FakePrivacyRepository()
        ..consentError = const ConsentRejectedException();
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await _accept(tester);
      await tester.pumpAndSettle();

      expect(find.text(privacyConsentFailedMessage), findsOneWidget);
      expect(
        find.byKey(const Key('privacy-consent-confirmation')),
        findsNothing,
      );
    });

    testWidgets('sesión expirada al consentir ofrece iniciar sesión', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakePrivacyRepository()
        ..consentError = const SessionExpiredException();
      final router = GoRouter(
        initialLocation: '/perfil',
        routes: [
          GoRoute(
            path: '/perfil',
            builder: (_, _) =>
                PrivacyNoticePage(userId: 'u1', repository: repo),
          ),
          GoRoute(path: '/login', builder: (_, _) => const Text('login')),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await _accept(tester);
      await tester.pumpAndSettle();

      expect(find.text(privacySessionExpiredMessage), findsOneWidget);
      expect(
        find.byKey(const Key('privacy-consent-confirmation')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('privacy-login')));
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('versión no soportada bloquea el consentimiento', (
      tester,
    ) async {
      final repo = FakePrivacyRepository(
        notice: PrivacyNotice(
          version: '3',
          date: DateTime(2026, 11, 16),
          sections: samplePrivacyNotice.sections,
        ),
      );
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text(privacyConsentVersionMessage), findsOneWidget);
      expect(find.byKey(const Key('privacy-consent-checkbox')), findsNothing);
      expect(find.text('Aceptar aviso'), findsNothing);
    });
  });
}
