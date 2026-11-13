import 'dart:async';

import 'package:fit_track_360/core/notifications/reminder_service.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:fit_track_360/design_system/widgets/ds_text_field.dart';
import 'package:fit_track_360/features/auth/data/logout_service.dart';
import 'package:fit_track_360/features/settings/domain/user_profile.dart';
import 'package:fit_track_360/features/settings/presentation/profile_page.dart';
import 'package:fit_track_360/features/settings/presentation/profile_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fakes.dart';

class _Deps {
  _Deps({
    FakeProfileRepository? repository,
    FakeReminderService? reminders,
    FakeBiometricService? biometrics,
    bool online = true,
    this.revokeFails = false,
  }) : repository = repository ?? FakeProfileRepository(),
       reminders = reminders ?? FakeReminderService(),
       biometrics = biometrics ?? FakeBiometricService(),
       connectivity = FakeConnectivityService(online: online);

  final FakeProfileRepository repository;
  final FakeReminderService reminders;
  final FakeBiometricService biometrics;
  final FakeConnectivityService connectivity;
  final storage = FakeSessionStorage();
  final bool revokeFails;
}

Future<void> _pump(WidgetTester tester, _Deps deps) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/app/perfil',
    routes: [
      GoRoute(
        path: '/app/perfil',
        builder: (context, state) => ProfilePage(
          repository: deps.repository,
          reminderService: deps.reminders,
          biometricService: deps.biometrics,
          connectivityService: deps.connectivity,
          logoutService: LogoutService(
            storage: deps.storage,
            revoke: ({required refreshToken}) async {
              if (deps.revokeFails) throw Exception('sin red');
            },
          ),
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const Text('login')),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(DsTextField, label),
  matching: find.byType(EditableText),
);

Switch _switch(WidgetTester tester, String key) => tester.widget<Switch>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(Switch)),
);

void main() {
  group('estados remotos', () {
    testWidgets('loading y luego datos del usuario, metas y resumen', (
      tester,
    ) async {
      final completer = Completer<void>();
      final deps = _Deps();
      final repo = deps.repository;
      final gated = _GatedRepository(repo, completer.future);
      final router = GoRouter(
        initialLocation: '/p',
        routes: [
          GoRoute(
            path: '/p',
            builder: (_, _) => ProfilePage(
              repository: gated,
              reminderService: deps.reminders,
              biometricService: deps.biometrics,
              connectivityService: deps.connectivity,
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
      expect(find.text('2000 kcal'), findsOneWidget);
      expect(
        find.text('Sesiones de entrenamiento registradas: 3'),
        findsOneWidget,
      );
    });

    testWidgets('títulos y valores usan textPrimary, no el color de CTA', (
      tester,
    ) async {
      await _pump(tester, _Deps());
      for (final key in [
        'profile-name',
        'goals-title',
        'goals-calories-value',
      ]) {
        final text = tester.widget<Text>(find.byKey(Key(key)));
        expect(text.style?.color, AppColors.textPrimary, reason: key);
        expect(text.style?.color, isNot(AppColors.textOnAccent), reason: key);
      }
    });

    testWidgets('error con reintentar', (tester) async {
      final deps = _Deps();
      deps.repository.fetchError = Exception('500');
      await _pump(tester, deps);
      expect(find.text('No pudimos cargar tu perfil.'), findsOneWidget);

      deps.repository.fetchError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
    });

    testWidgets('vacío cuando el API no devuelve perfil', (tester) async {
      final deps = _Deps(repository: FakeProfileRepository()..profile = null);
      await _pump(tester, deps);
      expect(find.text('Aún no hay datos de perfil.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('sin red muestra el OfflineBanner', (tester) async {
      await _pump(tester, _Deps(online: false));
      expect(find.text('Sin conexión'), findsOneWidget);
    });
  });

  group('edición', () {
    testWidgets('guarda nombre y metas y se recuperan al volver', (
      tester,
    ) async {
      final deps = _Deps();
      await _pump(tester, deps);
      await tester.enterText(_field('Nombre'), 'Bea');
      await tester.enterText(_field('Calorías (kcal)'), '1800');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(deps.repository.updates, hasLength(1));
      expect(deps.repository.updates.single.displayName, 'Bea');
      expect(find.text('Cambios guardados.'), findsOneWidget);

      // Se vuelve a abrir la vista: el GET trae lo guardado.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _Deps(repository: deps.repository));
      expect(find.text('Bea'), findsWidgets);
      expect(find.text('1800 kcal'), findsOneWidget);
    });

    for (final (label, value, message) in [
      (
        'Calorías (kcal)',
        '0',
        'La meta de calorías debe estar entre 1 y 20000.',
      ),
      ('Proteína (g)', '-1', 'El macro debe estar entre 0 y 2000 g.'),
      ('Nombre', '', 'Escribe tu nombre.'),
    ]) {
      testWidgets('rechaza $label = "$value" sin llamar al API', (
        tester,
      ) async {
        final deps = _Deps();
        await _pump(tester, deps);
        await tester.enterText(_field(label), value);
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(deps.repository.updates, isEmpty);
      });
    }
  });

  group('P3 recordatorio diario', () {
    testWidgets('permiso concedido: programa y guarda', (tester) async {
      final deps = _Deps();
      await _pump(tester, deps);
      await tester.tap(find.byKey(const Key('reminder-switch')));
      await tester.pumpAndSettle();
      expect(deps.reminders.requests, 1);
      expect(deps.reminders.scheduled, 1);
      expect(deps.repository.profile!.preferences.notificationsEnabled, isTrue);
      expect(_switch(tester, 'reminder-switch').value, isTrue);
    });

    testWidgets('permiso denegado: el interruptor vuelve a apagado', (
      tester,
    ) async {
      final deps = _Deps(
        reminders: FakeReminderService(permission: ReminderPermission.denied),
      );
      await _pump(tester, deps);
      await tester.tap(find.byKey(const Key('reminder-switch')));
      await tester.pumpAndSettle();
      expect(_switch(tester, 'reminder-switch').value, isFalse);
      expect(find.text(reminderDeniedMessage), findsOneWidget);
      expect(find.text('Abrir ajustes'), findsNothing);
      expect(deps.reminders.scheduled, 0);
      expect(deps.repository.updates, isEmpty);
    });

    testWidgets('denegado permanente: ofrece Abrir ajustes', (tester) async {
      final deps = _Deps(
        reminders: FakeReminderService(
          permission: ReminderPermission.permanentlyDenied,
        ),
      );
      await _pump(tester, deps);
      await tester.tap(find.byKey(const Key('reminder-switch')));
      await tester.pumpAndSettle();
      expect(_switch(tester, 'reminder-switch').value, isFalse);
      expect(find.text(reminderPermanentlyDeniedMessage), findsOneWidget);
      await tester.tap(find.text('Abrir ajustes'));
      await tester.pumpAndSettle();
      expect(deps.reminders.settingsOpened, 1);
    });

    testWidgets('no soportado: la fila se degrada sin romper', (tester) async {
      final deps = _Deps(reminders: FakeReminderService(supported: false));
      await _pump(tester, deps);
      expect(
        find.text('Tu dispositivo no admite recordatorios por ahora.'),
        findsOneWidget,
      );
      expect(_switch(tester, 'reminder-switch').onChanged, isNull);
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
    });
  });

  group('O1 biometría', () {
    testWidgets('no disponible: la opción se oculta', (tester) async {
      await _pump(
        tester,
        _Deps(biometrics: FakeBiometricService(available: false)),
      );
      expect(find.byKey(const Key('biometric-switch')), findsNothing);
      expect(find.text('Desbloqueo con biometría'), findsNothing);
    });

    testWidgets('autenticación fallida: no se activa', (tester) async {
      final deps = _Deps(biometrics: FakeBiometricService(succeeds: false));
      await _pump(tester, deps);
      await tester.tap(find.byKey(const Key('biometric-switch')));
      await tester.pumpAndSettle();
      expect(deps.biometrics.attempts, 1);
      expect(deps.repository.updates, isEmpty);
      expect(_switch(tester, 'biometric-switch').value, isFalse);
      expect(find.text(biometricFailedMessage), findsOneWidget);
    });

    testWidgets('autenticación correcta: guarda biometricEnabled', (
      tester,
    ) async {
      final deps = _Deps();
      await _pump(tester, deps);
      await tester.tap(find.byKey(const Key('biometric-switch')));
      await tester.pumpAndSettle();
      expect(deps.repository.profile!.preferences.biometricEnabled, isTrue);
      expect(_switch(tester, 'biometric-switch').value, isTrue);
    });
  });

  group('datos y sesión', () {
    testWidgets('exportación 404 se degrada con mensaje', (tester) async {
      final deps = _Deps();
      await _pump(tester, deps);
      await tester.tap(find.text('Exportar mis datos'));
      await tester.pumpAndSettle();
      expect(
        find.text('La exportación aún no está disponible. Intenta más tarde.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
    });

    testWidgets('exportación disponible muestra el JSON', (tester) async {
      final deps = _Deps();
      deps.repository.exportJson = '{"profile":{"displayName":"Ana"}}';
      await _pump(tester, deps);
      await tester.tap(find.text('Exportar mis datos'));
      await tester.pumpAndSettle();
      expect(find.text('Tus datos exportados'), findsOneWidget);
      expect(find.textContaining('"displayName":"Ana"'), findsOneWidget);
    });

    testWidgets('aviso de privacidad abre el texto del aviso', (tester) async {
      await _pump(tester, _Deps());
      await tester.tap(find.text('Aviso de privacidad'));
      await tester.pumpAndSettle();
      expect(find.text('Responsable del tratamiento'), findsOneWidget);
    });

    testWidgets('cerrar sesión limpia la sesión aunque el API falle', (
      tester,
    ) async {
      final deps = _Deps(revokeFails: true);
      await _pump(tester, deps);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(deps.storage.accessToken, isNull);
      expect(find.text('login'), findsOneWidget);
    });
  });
}

/// Retrasa el GET para observar el estado Loading.
class _GatedRepository extends FakeProfileRepository {
  _GatedRepository(this._inner, this._gate);

  final FakeProfileRepository _inner;
  final Future<void> _gate;

  @override
  Future<UserProfile?> fetchProfile() async {
    await _gate;
    return _inner.fetchProfile();
  }
}
