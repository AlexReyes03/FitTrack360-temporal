import 'dart:async';
import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/core/notifications/fcm_messaging_gateway.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/home/domain/steps_sensor.dart';
import 'package:fit_track_360/features/home/presentation/app_shell_page.dart';
import 'package:fit_track_360/features/home/presentation/home_shell_page.dart';
import 'package:fit_track_360/features/home/presentation/widgets/glass_bottom_nav_bar.dart';
import 'package:fit_track_360/features/notifications/data/device_token_api.dart';
import 'package:fit_track_360/features/notifications/data/push_device_lifecycle_service.dart';
import 'package:fit_track_360/features/notifications/presentation/push_device_scope.dart';
import 'package:fit_track_360/features/settings/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../settings/fakes.dart' as settings_fakes;
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
  int disposeCalls = 0;
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

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _FakeFcmGateway implements FcmMessagingGateway {
  _FakeFcmGateway({this.token = 'tok-initial'});

  String? token;
  final _refreshController = StreamController<String>.broadcast();

  bool get hasRefreshListener => _refreshController.hasListener;

  void emitRefresh(String nextToken) {
    token = nextToken;
    _refreshController.add(nextToken);
  }

  Future<void> close() => _refreshController.close();

  @override
  bool get isSupported => true;

  @override
  String? get platformName => 'android';

  @override
  Future<FcmAuthorizationStatus> getNotificationSettings() async =>
      FcmAuthorizationStatus.authorized;

  @override
  Future<FcmAuthorizationStatus> requestPermission() async =>
      FcmAuthorizationStatus.authorized;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _refreshController.stream;

  @override
  Future<void> deleteToken() async {}
}

class _FakeDeviceTokenClient implements DeviceTokenClient {
  final registered = <({String token, String platform})>[];
  final revoked = <String>[];

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    registered.add((token: token, platform: platform));
  }

  @override
  Future<void> revokeDeviceToken({required String token}) async {
    revoked.add(token);
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
      'AppShellPage con HomeShellPage y ProfilePage comparten el mismo PushDeviceScope al cerrar sesión',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final previousStorage = appSessionStorage;
        appSessionStorage = storage;
        addTearDown(() => appSessionStorage = previousStorage);

        final push = _FakePushDeviceLifecycle();
        final profileRepo = settings_fakes.FakeProfileRepository(
          profile: settings_fakes.sampleProfileWithNotifications(true),
        );
        final router = GoRouter(
          initialLocation: '/app',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) =>
                  AppShellPage(navigationShell: navigationShell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/app',
                      builder: (context, state) => HomeShellPage(
                        apiClient: ApiClient(
                          storage: storage,
                          httpClient: MockClient((request) async {
                            if (request.url.path.endsWith('/users/me')) {
                              return _profile(notificationsEnabled: true);
                            }
                            return _route(request);
                          }),
                        ),
                        sessionStorage: storage,
                        connectivityService: FakeConnectivityService(
                          online: true,
                        ),
                        stepsSensor: FakeStepsSensor(
                          snapshots: [StepsSnapshot.unavailableDevice],
                        ),
                      ),
                    ),
                  ],
                ),
                for (final path in const [
                  '/app/entrenamientos',
                  '/app/comidas',
                  '/app/ejercicios',
                  '/app/progreso',
                ])
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: path,
                        builder: (context, state) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/app/perfil',
                      builder: (context, state) => ProfilePage(
                        repository: profileRepo,
                        reminderService: settings_fakes.FakeReminderService(),
                        biometricService: settings_fakes.FakeBiometricService(),
                        exportSharer: settings_fakes.FakeExportSharer(),
                        connectivityService:
                            settings_fakes.FakeConnectivityService(
                              online: true,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const Text('Pantalla login'),
            ),
          ],
        );

        await tester.pumpWidget(
          PushDeviceScope(
            service: push,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(push.syncCalls, hasLength(1));

        await tester.tap(
          find.descendant(
            of: find.byType(GlassBottomNavBar),
            matching: find.text('Perfil'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('profile-logout-button')));
        await tester.pumpAndSettle();

        expect(push.revokeCalls, 1);
        expect(storage.accessToken, isNull);
        expect(find.text('Pantalla login'), findsOneWidget);
        expect(push.disposeCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AppShellPage, HomeShellPage y ProfilePage comparten el mismo PushDeviceScope y apagar P3 detiene onTokenRefresh',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final gateway = _FakeFcmGateway(token: 'tok-initial');
        final tokenApi = _FakeDeviceTokenClient();
        final sharedPush = PushDeviceLifecycleService(
          gateway: gateway,
          api: tokenApi,
          storage: storage,
        );
        addTearDown(() async {
          await sharedPush.dispose();
          await gateway.close();
        });

        final profileRepo = settings_fakes.FakeProfileRepository(
          profile: settings_fakes.sampleProfileWithNotifications(true),
        );
        final router = GoRouter(
          initialLocation: '/app',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) =>
                  AppShellPage(navigationShell: navigationShell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/app',
                      builder: (context, state) => HomeShellPage(
                        apiClient: ApiClient(
                          storage: storage,
                          httpClient: MockClient((request) async {
                            if (request.url.path.endsWith('/users/me')) {
                              return _profile(notificationsEnabled: true);
                            }
                            return _route(request);
                          }),
                        ),
                        sessionStorage: storage,
                        connectivityService: FakeConnectivityService(
                          online: true,
                        ),
                        stepsSensor: FakeStepsSensor(
                          snapshots: [StepsSnapshot.unavailableDevice],
                        ),
                      ),
                    ),
                  ],
                ),
                for (final path in const [
                  '/app/entrenamientos',
                  '/app/comidas',
                  '/app/ejercicios',
                  '/app/progreso',
                ])
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: path,
                        builder: (context, state) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/app/perfil',
                      builder: (context, state) => ProfilePage(
                        repository: profileRepo,
                        reminderService: settings_fakes.FakeReminderService(),
                        biometricService: settings_fakes.FakeBiometricService(),
                        exportSharer: settings_fakes.FakeExportSharer(),
                        connectivityService:
                            settings_fakes.FakeConnectivityService(
                              online: true,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const Text('Pantalla login'),
            ),
          ],
        );

        await tester.pumpWidget(
          PushDeviceScope(
            service: sharedPush,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(tokenApi.registered, [
          (token: 'tok-initial', platform: 'android'),
        ]);
        expect(gateway.hasRefreshListener, isTrue);

        // Una rotación de token mientras P3 está encendido se registra.
        gateway.emitRefresh('tok-rotated-1');
        await tester.pumpAndSettle();
        expect(tokenApi.registered.map((e) => e.token), [
          'tok-initial',
          'tok-rotated-1',
        ]);

        // Navega a Perfil por la barra y apaga el interruptor P3 usando el mismo servicio del scope.
        await tester.tap(
          find.descendant(
            of: find.byType(GlassBottomNavBar),
            matching: find.text('Perfil'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reminder-switch')), findsOneWidget);

        expect(
          PushDeviceScope.maybeOf(tester.element(find.byType(ProfilePage))),
          same(sharedPush),
        );
        expect(gateway.hasRefreshListener, isTrue);

        await tester.tap(find.byKey(const Key('reminder-switch')));
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();

        expect(profileRepo.profile!.preferences.notificationsEnabled, isFalse);
        expect(gateway.hasRefreshListener, isFalse);
        expect(tokenApi.revoked, ['tok-rotated-1']);

        // Vuelve a Inicio por la barra: un onTokenRefresh posterior no vuelve a registrar.
        await tester.tap(
          find.descendant(
            of: find.byType(GlassBottomNavBar),
            matching: find.text('Inicio'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hola, Ana'), findsOneWidget);

        gateway.emitRefresh('tok-after-disable');
        await tester.pumpAndSettle();
        expect(tokenApi.registered.map((e) => e.token), [
          'tok-initial',
          'tok-rotated-1',
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'consume PushDeviceScope sin llamar dispose() al desmontar el shell ni sobre servicio inyectado',
      (tester) async {
        final scopedPush = _FakePushDeviceLifecycle();
        final router = GoRouter(
          initialLocation: '/app',
          routes: [
            GoRoute(
              path: '/app',
              builder: (context, state) => HomeShellPage(
                apiClient: ApiClient(
                  storage: storage,
                  httpClient: MockClient((request) async {
                    if (request.url.path.endsWith('/users/me')) {
                      return _profile(notificationsEnabled: true);
                    }
                    return _route(request);
                  }),
                ),
                sessionStorage: storage,
                connectivityService: FakeConnectivityService(online: true),
                stepsSensor: FakeStepsSensor(
                  snapshots: [StepsSnapshot.unavailableDevice],
                ),
              ),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const Text('Pantalla login'),
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
        expect(scopedPush.syncCalls, hasLength(1));

        // Desmonta HomeShellPage: el dueño del servicio es PushDeviceScope, no el shell.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(scopedPush.disposeCalls, 0);

        // Tampoco dispone un servicio inyectado por parámetro.
        final injectedPush = _FakePushDeviceLifecycle();
        await _pumpShell(
          tester,
          connectivity: FakeConnectivityService(online: true),
          storage: storage,
          pushDeviceService: injectedPush,
          client: MockClient((request) async {
            if (request.url.path.endsWith('/users/me')) {
              return _profile(notificationsEnabled: true);
            }
            return _route(request);
          }),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(injectedPush.disposeCalls, 0);
      },
    );

    testWidgets(
      'montado de forma aislada sin PushDeviceScope crea y libera su propia instancia sin errores',
      (tester) async {
        await _pumpShell(
          tester,
          connectivity: FakeConnectivityService(online: true),
          storage: storage,
          client: MockClient((request) async {
            if (request.url.path.endsWith('/users/me')) {
              return _profile(notificationsEnabled: true);
            }
            return _route(request);
          }),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
