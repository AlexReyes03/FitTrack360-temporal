import 'dart:async';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/notifications/reminder_service.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/design_system/components/primary_button.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:fit_track_360/design_system/widgets/ds_text_field.dart';
import 'package:fit_track_360/features/auth/data/logout_service.dart';
import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_scope.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_view_model.dart';
import 'package:fit_track_360/features/notifications/presentation/push_device_scope.dart';
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
    FakeExportSharer? sharer,
    FakePrivacyRepository? privacy,
    FakePushDeviceLifecycle? push,
    bool online = true,
    this.revokeFails = false,
  }) : repository = repository ?? FakeProfileRepository(),
       sharer = sharer ?? FakeExportSharer(),
       privacy = privacy ?? FakePrivacyRepository(),
       reminders = reminders ?? FakeReminderService(),
       biometrics = biometrics ?? FakeBiometricService(),
       push = push ?? FakePushDeviceLifecycle(),
       connectivity = FakeConnectivityService(online: online);

  final FakeProfileRepository repository;
  final FakeReminderService reminders;
  final FakeBiometricService biometrics;
  final FakeExportSharer sharer;
  final FakePrivacyRepository privacy;
  final FakePushDeviceLifecycle push;
  final FakeConnectivityService connectivity;
  final storage = FakeSessionStorage();
  final revokedTokens = <String>[];
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
          exportSharer: deps.sharer,
          privacyRepository: deps.privacy,
          connectivityService: deps.connectivity,
          pushDeviceService: deps.push,
          logoutService: LogoutService(
            storage: deps.storage,
            pushDeviceService: deps.push,
            revoke: ({required idToken}) async {
              deps.revokedTokens.add(idToken);
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
              exportSharer: deps.sharer,
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

    testWidgets('API sin workoutCount: el resumen se degrada con aviso', (
      tester,
    ) async {
      await _pump(
        tester,
        _Deps(repository: FakeProfileRepository()..workouts = null),
      );
      expect(find.byKey(const Key('profile-workout-count')), findsNothing);
      expect(
        find.text('El resumen histórico no está disponible por ahora.'),
        findsOneWidget,
      );
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
      // El PATCH no trae workoutCount: el resumen del GET se conserva.
      expect(
        find.text('Sesiones de entrenamiento registradas: 3'),
        findsOneWidget,
      );

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
      expect(deps.sharer.shared, isEmpty);
    });

    testWidgets('exportación disponible se comparte como archivo JSON', (
      tester,
    ) async {
      final deps = _Deps();
      deps.repository.exportJson = '{"profile":{"displayName":"Ana"}}';
      await _pump(tester, deps);
      await tester.tap(find.text('Exportar mis datos'));
      await tester.pumpAndSettle();

      final shared = deps.sharer.shared.single;
      expect(shared.json, '{"profile":{"displayName":"Ana"}}');
      expect(
        shared.fileName,
        matches(RegExp(r'^fittrack360-export-\d{4}-\d{2}-\d{2}\.json$')),
      );
      // iPad exige un origen para anclar la hoja de compartir.
      expect(shared.origin, isNotNull);
      expect(shared.origin!.isEmpty, isFalse);
      expect(find.text('Tus datos exportados'), findsNothing);
    });

    testWidgets('si compartir falla, muestra el JSON en el diálogo', (
      tester,
    ) async {
      final deps = _Deps(sharer: FakeExportSharer(error: Exception('plugin')));
      deps.repository.exportJson = '{"profile":{"displayName":"Ana"}}';
      await _pump(tester, deps);
      await tester.tap(find.text('Exportar mis datos'));
      await tester.pumpAndSettle();
      expect(find.text('Tus datos exportados'), findsOneWidget);
      expect(find.textContaining('"displayName":"Ana"'), findsOneWidget);
      expect(find.text(exportShareFailedMessage), findsOneWidget);
    });

    testWidgets('exportación con sesión expirada pide iniciar sesión', (
      tester,
    ) async {
      final deps = _Deps();
      deps.repository.exportError = const SessionExpiredException();
      await _pump(tester, deps);
      await tester.tap(find.text('Exportar mis datos'));
      await tester.pumpAndSettle();

      expect(find.text('Sesión expirada'), findsOneWidget);
      expect(find.text(exportUnavailableMessage), findsNothing);
      expect(deps.sharer.shared, isEmpty);

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('aviso de privacidad abre la versión vigente del API', (
      tester,
    ) async {
      final deps = _Deps();
      await _pump(tester, deps);
      await tester.tap(find.text('Aviso de privacidad'));
      await tester.pumpAndSettle();
      expect(find.text('Versión 2 · 16 de noviembre de 2026'), findsOneWidget);
      expect(find.text('Cuenta'), findsOneWidget);
      expect(find.textContaining('[NOMBRE'), findsNothing);
      expect(deps.privacy.noticeCalls, 1);
    });

    testWidgets('eliminar cuenta: cancelar no llama al API', (tester) async {
      final deps = _Deps();
      await _pump(tester, deps);
      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Esta acción no se puede deshacer'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(deps.repository.deleteCalls, 0);
      expect(deps.storage.accessToken, 'access');
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
      expect(find.text('Cuenta eliminada'), findsNothing);
    });

    testWidgets(
      'eliminar cuenta confirmada: limpia la sesión antes del diálogo',
      (tester) async {
        final deps = _Deps();
        await _pump(tester, deps);
        await tester.tap(find.text('Eliminar mi cuenta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        expect(deps.repository.deleteCalls, 1);
        expect(find.text('Cuenta eliminada'), findsOneWidget);
        expect(
          find.textContaining('El servidor confirmó la eliminación'),
          findsOneWidget,
        );

        // El 204 ya limpió los tokens aunque el diálogo siga abierto, sin
        // intentar revocar una sesión que el servidor ya eliminó.
        expect(deps.storage.accessToken, isNull);
        expect(deps.storage.refreshToken, isNull);
        expect(deps.revokedTokens, isEmpty);
        expect(deps.push.revokeCalls, 0);

        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();

        expect(deps.storage.accessToken, isNull);
        expect(find.text('login'), findsOneWidget);
      },
    );

    testWidgets(
      'eliminar cuenta: la limpieza no depende de cerrar el diálogo',
      (tester) async {
        final deps = _Deps();
        await _pump(tester, deps);
        await tester.tap(find.text('Eliminar mi cuenta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        expect(find.text('Cuenta eliminada'), findsOneWidget);
        expect(deps.storage.accessToken, isNull);

        // Desmontar la vista con el diálogo abierto no restaura la sesión.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        expect(deps.storage.accessToken, isNull);
        expect(deps.storage.refreshToken, isNull);
      },
    );

    testWidgets('eliminar cuenta: la limpieza sigue si la vista se desmonta', (
      tester,
    ) async {
      final deps = _Deps();
      final gate = Completer<void>();
      deps.repository.deleteGate = gate.future;
      await _pump(tester, deps);
      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump();

      // La vista desaparece mientras el DELETE sigue en curso.
      await tester.pumpWidget(const SizedBox());
      expect(deps.storage.accessToken, 'access');

      gate.complete();
      await tester.pumpAndSettle();

      expect(deps.storage.accessToken, isNull);
      expect(deps.storage.refreshToken, isNull);
    });

    testWidgets('eliminar cuenta con error HTTP no informa éxito', (
      tester,
    ) async {
      final deps = _Deps();
      deps.repository.deleteError = Exception('500');
      await _pump(tester, deps);
      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text(deleteAccountFailedMessage), findsOneWidget);
      expect(find.text('Cuenta eliminada'), findsNothing);
      expect(deps.storage.accessToken, 'access');
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
      expect(find.text('login'), findsNothing);
    });

    testWidgets('eliminar cuenta con sesión expirada ofrece iniciar sesión', (
      tester,
    ) async {
      final deps = _Deps();
      deps.repository.deleteError = const SessionExpiredException();
      await _pump(tester, deps);
      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Cuenta eliminada'), findsNothing);
      expect(find.text('Sesión expirada'), findsOneWidget);
      expect(deps.storage.accessToken, 'access');
      expect(find.text('login'), findsNothing);

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('eliminar cuenta muestra progreso y evita duplicados', (
      tester,
    ) async {
      final deps = _Deps();
      final gate = Completer<void>();
      deps.repository.deleteGate = gate.future;
      await _pump(tester, deps);
      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump();

      expect(find.text('Eliminando cuenta...'), findsOneWidget);
      await tester.tap(find.text('Eliminando cuenta...'));
      await tester.pump();
      expect(deps.repository.deleteCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(deps.repository.deleteCalls, 1);
      expect(find.text('Cuenta eliminada'), findsOneWidget);
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

    testWidgets(
      'interruptor P3 y cerrar sesión disparan registro/revocación FCM sin cambiar textos ni bloquear /login',
      (tester) async {
        final push = FakePushDeviceLifecycle();
        final deps = _Deps(push: push);
        await _pump(tester, deps);

        expect(find.text('Recordatorio diario'), findsOneWidget);
        expect(
          find.text(
            'Te avisamos una vez al día para entrenar o registrar '
            'tu comida. Te pediremos permiso al activarlo.',
          ),
          findsOneWidget,
        );
        expect(find.text('Cerrar sesión'), findsOneWidget);
        expect(_switch(tester, 'reminder-switch').value, isFalse);

        // Encender P3 registra el token FCM solicitando permiso si falta.
        await tester.tap(find.byKey(const Key('reminder-switch')));
        await tester.pumpAndSettle();
        expect(_switch(tester, 'reminder-switch').value, isTrue);
        expect(push.syncCalls, hasLength(1));
        expect(push.syncCalls.single.notificationsEnabled, isTrue);
        expect(push.syncCalls.single.requestPermissionIfNeeded, isTrue);
        expect(find.text('Recordatorio diario'), findsOneWidget);

        // Apagar P3 revoca el token FCM y mantiene los textos intactos.
        await tester.tap(find.byKey(const Key('reminder-switch')));
        await tester.pumpAndSettle();
        expect(_switch(tester, 'reminder-switch').value, isFalse);
        expect(push.revokeCalls, 1);
        expect(find.text('Recordatorio diario'), findsOneWidget);

        // Cerrar sesión revoca el token FCM aunque falle y navega a /login.
        push.revokeError = Exception('sin red');
        await tester.tap(find.text('Cerrar sesión'));
        await tester.pumpAndSettle();
        expect(push.revokeCalls, 2);
        expect(deps.storage.accessToken, isNull);
        expect(find.text('login'), findsOneWidget);
      },
    );

    testWidgets(
      'ProfilePage sin logoutService externo cablea pushDeviceService al cerrar sesión',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final previousStorage = appSessionStorage;
        final fakeStorage = FakeSessionStorage()..accessToken = null;
        appSessionStorage = fakeStorage;
        addTearDown(() => appSessionStorage = previousStorage);

        final push = FakePushDeviceLifecycle();
        final router = GoRouter(
          initialLocation: '/app/perfil',
          routes: [
            GoRoute(
              path: '/app/perfil',
              builder: (context, state) => ProfilePage(
                repository: FakeProfileRepository(),
                reminderService: FakeReminderService(),
                biometricService: FakeBiometricService(),
                exportSharer: FakeExportSharer(),
                connectivityService: FakeConnectivityService(),
                pushDeviceService: push,
              ),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const Text('login'),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cerrar sesión'));
        await tester.pumpAndSettle();

        expect(push.revokeCalls, 1);
        expect(find.text('login'), findsOneWidget);
      },
    );

    testWidgets(
      'cerrar sesión limpia NotificationsScope en memoria antes de ir a login',
      (tester) async {
        final deps = _Deps();
        final notifications = NotificationsViewModel(
          initialNotifications: [
            AppNotification(
              id: 'n-1',
              title: 'Nuevo inicio de sesión',
              message: 'Acceso desde Android.',
              type: AppNotificationType.newLogin,
              createdAt: DateTime(2026, 11, 22, 10),
            ),
          ],
        );
        addTearDown(notifications.dispose);

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
                exportSharer: deps.sharer,
                connectivityService: deps.connectivity,
                logoutService: LogoutService(
                  storage: deps.storage,
                  revoke: ({required idToken}) async {},
                ),
              ),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const Text('login'),
            ),
          ],
        );

        await tester.pumpWidget(
          NotificationsScope(
            notifier: notifications,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(notifications.unreadCount, 1);
        expect(notifications.notifications, hasLength(1));

        await tester.tap(find.byKey(const Key('profile-logout-button')));
        await tester.pumpAndSettle();

        expect(notifications.notifications, isEmpty);
        expect(notifications.unreadCount, 0);
        expect(notifications.hasLoaded, isFalse);
        expect(find.text('login'), findsOneWidget);
      },
    );

    testWidgets(
      'el botón Cerrar sesión usa estilo rojo destructivo y texto claro',
      (tester) async {
        await _pump(tester, _Deps());

        final buttonFinder = find.byKey(const Key('profile-logout-button'));
        expect(buttonFinder, findsOneWidget);

        final button = tester.widget<PrimaryButton>(buttonFinder);
        expect(button.label, 'Cerrar sesión');
        expect(button.variant, PrimaryButtonVariant.destructive);

        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: buttonFinder,
            matching: find.byType(AnimatedContainer),
          ),
        );
        final decoration = container.decoration! as BoxDecoration;
        final gradient = decoration.gradient! as LinearGradient;
        expect(
          gradient.colors,
          containsAll([
            AppColors.dangerSolidTop,
            AppColors.dangerSolidMid,
            AppColors.dangerSolidBottom,
          ]),
        );

        final labelText = tester.widget<Text>(
          find.descendant(
            of: buttonFinder,
            matching: find.text('Cerrar sesión'),
          ),
        );
        expect(labelText.style?.color, AppColors.accentWhite);
      },
    );

    testWidgets('Cerrar sesión se deshabilita mientras cierra sesión', (
      tester,
    ) async {
      final revokeCompleter = Completer<void>();
      final deps = _Deps();
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
              exportSharer: deps.sharer,
              connectivityService: deps.connectivity,
              logoutService: LogoutService(
                storage: deps.storage,
                revoke: ({required idToken}) => revokeCompleter.future,
              ),
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Text('login'),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-logout-button')));
      await tester.pump();

      final busyButton = tester.widget<PrimaryButton>(
        find.byKey(const Key('profile-logout-button')),
      );
      expect(busyButton.label, 'Cerrando...');
      expect(busyButton.onPressed, isNull);

      revokeCompleter.complete();
      await tester.pumpAndSettle();
      expect(find.text('login'), findsOneWidget);
    });
  });

  group('ciclo de vida compartido PushDeviceScope (W13-7)', () {
    testWidgets(
      'consume PushDeviceScope para P3 y logout sin llamar dispose() al desmontar',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final previousStorage = appSessionStorage;
        appSessionStorage = FakeSessionStorage()..accessToken = null;
        addTearDown(() => appSessionStorage = previousStorage);

        final scopedPush = FakePushDeviceLifecycle();
        final router = GoRouter(
          initialLocation: '/app/perfil',
          routes: [
            GoRoute(
              path: '/app/perfil',
              builder: (context, state) => ProfilePage(
                repository: FakeProfileRepository(),
                reminderService: FakeReminderService(),
                biometricService: FakeBiometricService(),
                exportSharer: FakeExportSharer(),
                connectivityService: FakeConnectivityService(),
              ),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const Text('login'),
            ),
          ],
        );

        await tester.pumpWidget(
          PushDeviceScope(
            service: scopedPush,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reminder-switch')));
        await tester.pumpAndSettle();
        expect(scopedPush.syncCalls, hasLength(1));

        await tester.tap(find.byKey(const Key('reminder-switch')));
        await tester.pumpAndSettle();
        expect(scopedPush.revokeCalls, 1);

        await tester.tap(find.text('Cerrar sesión'));
        await tester.pumpAndSettle();
        expect(scopedPush.revokeCalls, 2);
        expect(find.text('login'), findsOneWidget);

        // Desmontar ProfilePage no debe disponer el servicio del PushDeviceScope.
        expect(scopedPush.disposeCalls, 0);
      },
    );

    testWidgets(
      'no llama dispose() sobre pushDeviceService inyectado al desmontar',
      (tester) async {
        final injectedPush = FakePushDeviceLifecycle();
        await _pump(tester, _Deps(push: injectedPush));

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(injectedPush.disposeCalls, 0);
      },
    );

    testWidgets(
      'aislada sin PushDeviceScope ni pushDeviceService crea y libera su propia instancia sin errores',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final router = GoRouter(
          initialLocation: '/app/perfil',
          routes: [
            GoRoute(
              path: '/app/perfil',
              builder: (context, state) => ProfilePage(
                repository: FakeProfileRepository(),
                reminderService: FakeReminderService(),
                biometricService: FakeBiometricService(),
                exportSharer: FakeExportSharer(),
                connectivityService: FakeConnectivityService(),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('profile-name')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'cambios de dependencias posteriores no reconstruyen ProfileViewModel ni limpian controllers',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final repo = FakeProfileRepository();
        final scopedPush = FakePushDeviceLifecycle();
        final textScale = ValueNotifier<double>(1.0);
        addTearDown(textScale.dispose);

        await tester.pumpWidget(
          PushDeviceScope(
            service: scopedPush,
            child: ValueListenableBuilder<double>(
              valueListenable: textScale,
              builder: (context, scale, child) => MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              child: MaterialApp(
                home: ProfilePage(
                  repository: repo,
                  reminderService: FakeReminderService(),
                  biometricService: FakeBiometricService(),
                  exportSharer: FakeExportSharer(),
                  connectivityService: FakeConnectivityService(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.fetchCalls, 1);

        await tester.enterText(_field('Nombre'), 'Ana Editada');
        textScale.value = 1.2;
        await tester.pumpAndSettle();

        expect(repo.fetchCalls, 1);
        expect(find.text('Ana Editada'), findsOneWidget);
        expect(scopedPush.disposeCalls, 0);
      },
    );
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
