import 'dart:async';
import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/home/domain/steps_sensor.dart';
import 'package:fit_track_360/features/home/presentation/home_shell_page.dart';
import 'package:fit_track_360/features/notifications/data/push_device_lifecycle_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_dashboard.dart';

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({required this.online});

  bool online;
  final _controller = StreamController<bool>.broadcast();

  void emit(bool value) {
    online = value;
    _controller.add(value);
  }

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  Future<bool> isOnline() async => online;
}

class FakeSessionStorage implements SessionStorage {
  String? accessToken = 'access';
  String? refreshToken;

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

class _FakePushDeviceLifecycle implements PushDeviceLifecycle {
  final syncCalls =
      <({bool notificationsEnabled, bool requestPermissionIfNeeded})>[];
  int revokeCalls = 0;
  Object? syncError;
  Object? revokeError;

  @override
  Future<void> syncForActiveSession({
    required bool notificationsEnabled,
    bool requestPermissionIfNeeded = false,
  }) async {
    syncCalls.add((
      notificationsEnabled: notificationsEnabled,
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    ));
    if (syncError != null) throw syncError!;
  }

  @override
  Future<void> deactivateAndRevoke() async {
    revokeCalls++;
    if (revokeError != null) throw revokeError!;
  }
}

http.Response _profile({bool? notificationsEnabled}) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'id': '1',
      'email': 'ana@test.com',
      'username': 'ana',
      'displayName': 'Ana',
      'createdAt': '2026-11-04T00:00:00.000Z',
      if (notificationsEnabled != null)
        'preferences': {
          'weightUnit': 'kg',
          'distanceUnit': 'km',
          'restSeconds': 90,
          'notificationsEnabled': notificationsEnabled,
          'biometricEnabled': false,
        },
    }),
  ),
  200,
);

http.Response _dashboardEmpty() => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'date': '2026-11-19',
      'utcOffsetMinutes': -360,
      'nutrition': {
        'mealsLogged': 0,
        'consumed': {'calories': 0, 'proteinG': 0, 'carbsG': 0, 'fatG': 0},
        'goals': {
          'dailyCalorieGoal': 2000,
          'proteinGoalG': 150,
          'carbsGoalG': 200,
          'fatGoalG': 60,
        },
        'remaining': {
          'calories': 2000,
          'proteinG': 150,
          'carbsG': 200,
          'fatG': 60,
        },
      },
      'session': null,
      'latestMetric': null,
    }),
  ),
  200,
  headers: {'content-type': 'application/json'},
);

Future<http.Response> _route(http.Request request) async {
  final path = request.url.path;
  if (path.endsWith('/users/me')) return _profile();
  if (path.contains('/dashboard/today')) return _dashboardEmpty();
  return http.Response('not found', 404);
}

Future<GoRouter> _pumpShell(
  WidgetTester tester, {
  required FakeConnectivityService connectivity,
  required FakeSessionStorage storage,
  required http.Client client,
  StepsSensor? stepsSensor,
  PushDeviceLifecycle? pushDeviceService,
  void Function()? onLoginNavigation,
}) async {
  final router = GoRouter(
    initialLocation: '/app',
    redirect: (context, state) {
      if (state.uri.path == '/login') onLoginNavigation?.call();
      return null;
    },
    routes: [
      GoRoute(
        path: '/app',
        builder: (context, state) => HomeShellPage(
          apiClient: ApiClient(storage: storage, httpClient: client),
          sessionStorage: storage,
          connectivityService: connectivity,
          stepsSensor:
              stepsSensor ??
              FakeStepsSensor(snapshots: [StepsSnapshot.unavailableDevice]),
          pushDeviceService: pushDeviceService,
        ),
      ),
      GoRoute(
        path: '/app/entrenamientos',
        builder: (context, state) => const Text('Pantalla entrenamientos'),
      ),
      GoRoute(
        path: '/app/comidas',
        builder: (context, state) => const Text('Pantalla comidas'),
      ),
      GoRoute(
        path: '/app/foto',
        builder: (context, state) => const Text('Pantalla foto'),
      ),
      GoRoute(
        path: '/app/ejercicios',
        builder: (context, state) => const Text('Pantalla ejercicios'),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Text('Pantalla login'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  return router;
}

void main() {
  late FakeSessionStorage storage;

  setUp(() => storage = FakeSessionStorage());

  testWidgets('con red no muestra el banner y carga el perfil', (tester) async {
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient(_route),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsNothing);
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Nutrición de hoy'), findsOneWidget);
  });

  testWidgets('sin red muestra el banner y conserva la sesion', (tester) async {
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: false),
      storage: storage,
      client: MockClient((_) async => throw http.ClientException('sin red')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Hola, bienvenido'), findsOneWidget);
    expect(storage.accessToken, 'access');
    expect(find.text('Pantalla login'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al recuperar la red quita el banner y recarga el perfil', (
    tester,
  ) async {
    var offline = true;
    final connectivity = FakeConnectivityService(online: false);
    await _pumpShell(
      tester,
      connectivity: connectivity,
      storage: storage,
      client: MockClient((request) async {
        if (offline) throw http.ClientException('sin red');
        return _route(request);
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hola, bienvenido'), findsOneWidget);

    offline = false;
    connectivity.emit(true);
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsNothing);
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reintentar sin red vuelve a pedir el perfil sin tumbar la app', (
    tester,
  ) async {
    var requests = 0;
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: false),
      storage: storage,
      client: MockClient((_) async {
        requests++;
        throw http.ClientException('sin red');
      }),
    );
    await tester.pumpAndSettle();
    // Perfil + dashboard en el arranque.
    expect(requests, 2);

    await tester.tap(find.text('Reintentar').first);
    await tester.pumpAndSettle();

    // Reintento pide de nuevo perfil + dashboard.
    expect(requests, 4);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no lanza dos cargas de perfil simultaneas', (tester) async {
    var profileRequests = 0;
    final pending = Completer<http.Response>();
    final connectivity = FakeConnectivityService(online: true);
    await _pumpShell(
      tester,
      connectivity: connectivity,
      storage: storage,
      client: MockClient((request) {
        if (request.url.path.endsWith('/users/me')) {
          profileRequests++;
          return pending.future;
        }
        return Future.value(_dashboardEmpty());
      }),
    );
    await tester.pump();
    expect(profileRequests, 1);

    connectivity.emit(true);
    await tester.pump();
    expect(profileRequests, 1);

    pending.complete(_profile());
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('sesion expirada sigue mandando a login', (tester) async {
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pantalla login'), findsOneWidget);
    expect(storage.accessToken, isNull);
  });

  testWidgets('sesion expirada navega a login una sola vez', (tester) async {
    var loginNavigations = 0;
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient((_) async => http.Response('{}', 401)),
      onLoginNavigation: () => loginNavigations++,
    );
    await tester.pumpAndSettle();

    expect(find.text('Pantalla login'), findsOneWidget);
    expect(loginNavigations, 1);
  });

  testWidgets(
    'sin permiso previo explica y pide los pasos solo al tocar la acción',
    (tester) async {
      final sensor = FakeStepsSensor(
        readyWithoutPrompt: false,
        snapshots: [const StepsSnapshot(steps: 4321)],
      );
      await _pumpShell(
        tester,
        connectivity: FakeConnectivityService(online: true),
        storage: storage,
        client: MockClient(_route),
        stepsSensor: sensor,
      );
      await tester.pumpAndSettle();

      expect(sensor.watchCalls, 0);
      expect(find.textContaining('sensor de actividad física'), findsOneWidget);

      await tester.ensureVisible(find.text('Mostrar mis pasos'));
      await tester.tap(find.text('Mostrar mis pasos'));
      await tester.pumpAndSettle();

      expect(sensor.watchCalls, 1);
      expect(find.text('4321'), findsOneWidget);
      expect(find.text('Mostrar mis pasos'), findsNothing);
    },
  );

  testWidgets('tras negar el permiso ofrece Reintentar y Ajustes', (
    tester,
  ) async {
    final sensor = FakeStepsSensor(
      snapshots: [
        const StepsSnapshot.unavailableFor(StepsUnavailableReason.blocked),
      ],
    );
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient(_route),
      stepsSensor: sensor,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Puedes activarlo después desde Ajustes'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Abrir ajustes'));
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
    expect(sensor.settingsOpened, 1);

    sensor.snapshots = [const StepsSnapshot(steps: 77)];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(sensor.watchCalls, 2);
    expect(find.text('77'), findsOneWidget);
  });

  testWidgets('cerrar sesion sin red limpia la sesion y va a login', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: false),
      storage: storage,
      client: MockClient((_) async => throw http.ClientException('sin red')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla login'), findsOneWidget);
    expect(storage.accessToken, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra estados empty del dashboard con datos vacíos', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient(_route),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Aún no registras comidas hoy'), findsOneWidget);
    expect(
      find.textContaining('Aún no tienes sesiones registradas'),
      findsOneWidget,
    );
    expect(find.text('No disponible'), findsOneWidget);
  });

  for (final (label, path, page) in [
    ('Entrenamiento', '/app/entrenamientos', 'Pantalla entrenamientos'),
    ('Comida', '/app/comidas', 'Pantalla comidas'),
    ('Foto progreso', '/app/foto', 'Pantalla foto'),
  ]) {
    testWidgets('el acceso rápido $label navega a $path', (tester) async {
      await _pumpShell(
        tester,
        connectivity: FakeConnectivityService(online: true),
        storage: storage,
        client: MockClient(_route),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.text(page), findsOneWidget);
    });
  }

  testWidgets('mantiene los accesos mientras el dashboard carga', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient((request) {
        if (request.url.path.endsWith('/users/me')) {
          return Future.value(_profile());
        }
        return pending.future;
      }),
      stepsSensor: FakeStepsSensor(snapshots: [const StepsSnapshot(steps: 1)]),
    );
    await tester.pump();

    expect(find.text('Entrenamiento'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Foto progreso'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);

    pending.complete(_dashboardEmpty());
    await tester.pumpAndSettle();
  });

  testWidgets('un error HTTP no se muestra como falta de conexión', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/users/me')) return _profile();
        return http.Response('{}', 500);
      }),
      stepsSensor: FakeStepsSensor(snapshots: [const StepsSnapshot(steps: 1)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsNothing);
    expect(
      find.text('No pudimos cargar tu resumen de nutrición.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNWidgets(3));

    await tester.ensureVisible(find.text('Entrenamiento'));
    await tester.tap(find.text('Entrenamiento'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla entrenamientos'), findsOneWidget);
  });

  testWidgets('Reintentar un bloque recupera sus datos', (tester) async {
    var dashboardCalls = 0;
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/users/me')) return _profile();
        dashboardCalls++;
        return dashboardCalls == 1
            ? http.Response('{}', 500)
            : _dashboardEmpty();
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos cargar tu resumen de nutrición.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Reintentar').first);
    await tester.tap(find.text('Reintentar').first);
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos cargar tu resumen de nutrición.'),
      findsNothing,
    );
    expect(find.textContaining('Aún no registras comidas hoy'), findsOneWidget);
    expect(dashboardCalls, 2);
  });

  testWidgets('no desborda en una pantalla estrecha', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient(_route),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Entrenamiento'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('la navegación heredada de Ejercicios sigue disponible', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient(_route),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ejercicios'));
    await tester.tap(find.text('Ejercicios'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla ejercicios'), findsOneWidget);
  });

  group('ciclo de vida FCM silencioso (W13-7)', () {
    testWidgets(
      'sincroniza silenciosamente sin pedir permiso cuando notificationsEnabled es true',
      (tester) async {
        final push = _FakePushDeviceLifecycle();
        await _pumpShell(
          tester,
          connectivity: FakeConnectivityService(online: true),
          storage: storage,
          pushDeviceService: push,
          client: MockClient((request) async {
            if (request.url.path.endsWith('/users/me')) {
              return _profile(notificationsEnabled: true);
            }
            return _route(request);
          }),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hola, Ana'), findsOneWidget);
        expect(push.syncCalls, hasLength(1));
        expect(push.syncCalls.single.notificationsEnabled, isTrue);
        expect(push.syncCalls.single.requestPermissionIfNeeded, isFalse);
      },
    );

    testWidgets(
      'respeta notificationsEnabled en false sin pedir permisos intrusivos',
      (tester) async {
        final push = _FakePushDeviceLifecycle();
        await _pumpShell(
          tester,
          connectivity: FakeConnectivityService(online: true),
          storage: storage,
          pushDeviceService: push,
          client: MockClient((request) async {
            if (request.url.path.endsWith('/users/me')) {
              return _profile(notificationsEnabled: false);
            }
            return _route(request);
          }),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hola, Ana'), findsOneWidget);
        expect(push.syncCalls, hasLength(1));
        expect(push.syncCalls.single.notificationsEnabled, isFalse);
        expect(push.syncCalls.single.requestPermissionIfNeeded, isFalse);
      },
    );

    testWidgets('degrada en silencio si la sincronización FCM falla', (
      tester,
    ) async {
      final push = _FakePushDeviceLifecycle()
        ..syncError = Exception('sin Play Services');
      await _pumpShell(
        tester,
        connectivity: FakeConnectivityService(online: true),
        storage: storage,
        pushDeviceService: push,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/users/me')) {
            return _profile(notificationsEnabled: true);
          }
          return _route(request);
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(push.syncCalls, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'cerrar sesión desde HomeShellPage revoca el token FCM antes de ir a login',
      (tester) async {
        final push = _FakePushDeviceLifecycle();
        await _pumpShell(
          tester,
          connectivity: FakeConnectivityService(online: true),
          storage: storage,
          pushDeviceService: push,
          client: MockClient((request) async {
            if (request.url.path.endsWith('/users/me')) {
              return _profile(notificationsEnabled: true);
            }
            return _route(request);
          }),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cerrar sesión'));
        await tester.pumpAndSettle();

        expect(push.revokeCalls, 1);
        expect(storage.accessToken, isNull);
        expect(find.text('Pantalla login'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
