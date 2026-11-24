import 'dart:convert';

import 'package:fit_track_360/app/app.dart';
import 'package:fit_track_360/app/router.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/auth/data/firebase_auth_service.dart';
import 'package:fit_track_360/features/auth/presentation/login_page.dart';
import 'package:fit_track_360/features/auth/presentation/register_page.dart';
import 'package:fit_track_360/features/home/presentation/app_shell_page.dart';
import 'package:fit_track_360/features/notifications/data/notifications_api_repository.dart';
import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
import 'package:fit_track_360/features/notifications/domain/notifications_repository.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_page.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_scope.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _EmptyStorage implements SessionStorage {
  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _MutableStorage implements SessionStorage {
  _MutableStorage(this.accessToken);

  String? accessToken;
  bool failForceRefresh = false;

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh && failForceRefresh) return null;
    return accessToken;
  }

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
  }
}

class _FakeAuthService extends Fake implements FirebaseAuthService {
  _FakeAuthService({this.onLogin, this.onGoogleLogin, this.onRegister});

  final VoidCallback? onLogin;
  final VoidCallback? onGoogleLogin;
  final VoidCallback? onRegister;

  static const _accountBUser = AuthUser(
    id: 'user-b',
    email: 'cuenta.b@test.com',
    username: 'cuentab',
    displayName: 'Cuenta B',
    firebaseUid: 'uid-b',
  );

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    onLogin?.call();
    return _accountBUser;
  }

  @override
  Future<AuthUser> loginWithGoogle({
    bool allowAutoRegister = false,
    bool privacyConsent = false,
    String privacyNoticeVersion = '2',
  }) async {
    onGoogleLogin?.call();
    return _accountBUser;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required bool privacyConsent,
    required String privacyNoticeVersion,
  }) async {
    onRegister?.call();
    return _accountBUser;
  }
}

class _ToggleExpiredRepository implements NotificationsRepository {
  bool throwExpired = false;
  int unread = 0;
  List<AppNotification> items = const <AppNotification>[];

  @override
  Future<List<AppNotification>> fetchNotifications({
    bool? isRead,
    AppNotificationType? type,
  }) async {
    if (throwExpired) throw const SessionExpiredException();
    return List<AppNotification>.unmodifiable(items);
  }

  @override
  Future<int> fetchUnreadCount() async {
    if (throwExpired) throw const SessionExpiredException();
    return unread;
  }

  @override
  Future<AppNotification?> updateRead(
    String id, {
    required bool isRead,
  }) async => null;

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> deleteNotification(String id) async {}

  @override
  Future<void> deleteAll() async {}
}

List<AppNotification> _seed() => [
  AppNotification(
    id: 'login',
    title: 'Nuevo inicio de sesión',
    message: 'Se inició sesión en un dispositivo Android.',
    type: AppNotificationType.newLogin,
    createdAt: DateTime(2026, 11, 22, 10),
  ),
];

GoRouter _buildSwitchAccountRouter({
  required FirebaseAuthService authService,
  String initialLocation = '/app',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) => resolveAppSessionRedirect(state),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(authService: authService),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterPage(authService: authService),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellPage(navigationShell: navigationShell),
        branches: [
          for (final path in const [
            '/app',
            '/app/entrenamientos',
            '/app/comidas',
            '/app/ejercicios',
            '/app/progreso',
            '/app/perfil',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) =>
                      const Center(child: Text('HOME_SHELL_BODY')),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: appNotificationsPath,
        builder: (context, state) => const NotificationsPage(),
      ),
    ],
  );
}

void main() {
  testWidgets('notifySessionCleared limpia el ViewModel de FitTrackApp', (
    tester,
  ) async {
    final previousStorage = appSessionStorage;
    appSessionStorage = _EmptyStorage();
    addTearDown(() => appSessionStorage = previousStorage);

    final viewModel = NotificationsViewModel(initialNotifications: _seed());
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(FitTrackApp(notifications: viewModel));
    // Resuelve el redirect asíncrono; sin sesión el splash va directo a
    // /login, que limpia los avisos al montar (#230).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(viewModel.notifications, isEmpty);

    // Vuelve a cargar para comprobar que notifySessionCleared limpia el VM.
    await viewModel.load();
    await tester.pump();

    expect(viewModel.notifications, hasLength(1));
    expect(viewModel.hasLoaded, isTrue);

    notifySessionCleared();
    await tester.pump();

    expect(viewModel.notifications, isEmpty);
    expect(viewModel.unreadCount, 0);
    expect(viewModel.hasLoaded, isFalse);
    expect(viewModel.sessionExpired, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'cuenta B nunca ve avisos ni conteo de cuenta A tras expiracion 401 y login',
    (tester) async {
      final storage = _MutableStorage('token-a');
      final previousStorage = appSessionStorage;
      appSessionStorage = storage;
      addTearDown(() => appSessionStorage = previousStorage);

      var accountAExpired = false;
      final mockHttp = MockClient((request) async {
        final authHeader = request.headers['Authorization'];
        if (authHeader == 'Bearer token-a') {
          if (accountAExpired) {
            return http.Response(
              jsonEncode({'message': 'Unauthorized'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/unread-count')) {
            return http.Response(
              jsonEncode({'unreadCount': 2}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'a-1',
                  'title': 'Aviso exclusivo de Cuenta A',
                  'body': 'Solo debe verlo la cuenta A.',
                  'type': 'new_login',
                  'isRead': false,
                  'createdAt': '2026-11-22T10:00:00.000Z',
                },
                {
                  'id': 'a-2',
                  'title': 'Segundo aviso de Cuenta A',
                  'body': 'Otro aviso privado de A.',
                  'type': 'reminder',
                  'isRead': false,
                  'createdAt': '2026-11-22T09:00:00.000Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (authHeader == 'Bearer token-b') {
          if (request.url.path.endsWith('/unread-count')) {
            return http.Response(
              jsonEncode({'unreadCount': 1}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'b-1',
                  'title': 'Aviso exclusivo de Cuenta B',
                  'body': 'Solo debe verlo la cuenta B.',
                  'type': 'reminder',
                  'isRead': false,
                  'createdAt': '2026-11-22T12:00:00.000Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode({'message': 'Unauthorized'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(storage: storage, httpClient: mockHttp);
      addTearDown(apiClient.dispose);

      final viewModel = NotificationsViewModel(
        repository: NotificationsApiRepository(apiClient),
      );
      addTearDown(viewModel.dispose);

      void onInvalidated() => viewModel.clearOnLogout();
      appSessionInvalidations.addListener(onInvalidated);
      addTearDown(() => appSessionInvalidations.removeListener(onInvalidated));

      final authService = _FakeAuthService(
        onLogin: () {
          storage.failForceRefresh = false;
          storage.accessToken = 'token-b';
        },
      );
      final router = _buildSwitchAccountRouter(authService: authService);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        NotificationsScope(
          notifier: viewModel,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // 1) Cuenta A en AppShellPage y NotificationsPage.
      expect(viewModel.unreadCount, 2);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Aviso exclusivo de Cuenta A'), findsOneWidget);
      expect(find.text('Segundo aviso de Cuenta A'), findsOneWidget);
      expect(viewModel.unreadCount, 2);

      // 2) Expiración 401 sin refresh posible + redirección a /login.
      accountAExpired = true;
      storage.failForceRefresh = true;
      await expectLater(
        () => apiClient.get('/api/v1/notifications/unread-count'),
        throwsA(isA<SessionExpiredException>()),
      );
      await tester.pump();

      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);
      expect(viewModel.hasLoaded, isFalse);

      // El guard redirige `/app` a `/login` porque la sesión fue limpiada.
      router.go('/app');
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      // 3) Cuenta B inicia sesión desde LoginPage y entra a AppShellPage.
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'cuenta.b@test.com');
      await tester.enterText(textFields.at(1), 'Password123!');
      final submitButton = find.text('Iniciar sesión');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.byType(AppShellPage), findsOneWidget);
      expect(viewModel.unreadCount, 1);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      expect(
        viewModel.notifications.any((n) => n.id.startsWith('a-')),
        isFalse,
      );

      // 4) Cuenta B abre NotificationsPage y solo ve sus propias notificaciones.
      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Aviso exclusivo de Cuenta B'), findsOneWidget);
      expect(find.text('Aviso exclusivo de Cuenta A'), findsNothing);
      expect(find.text('Segundo aviso de Cuenta A'), findsNothing);
      expect(viewModel.unreadCount, 1);
      expect(viewModel.sessionExpired, isFalse);
    },
  );

  testWidgets(
    'si sessionExpired queda activo, AppShellPage y NotificationsPage recargan la cuenta B sin errores previos',
    (tester) async {
      final storage = _MutableStorage('token-b');
      final previousStorage = appSessionStorage;
      appSessionStorage = storage;
      addTearDown(() => appSessionStorage = previousStorage);

      final repository = _ToggleExpiredRepository()..throwExpired = true;
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      // Deja sessionExpired = true y state = AsyncError(SessionExpiredException).
      await viewModel.load();
      expect(viewModel.sessionExpired, isTrue);
      expect(viewModel.hasLoaded, isFalse);

      repository
        ..throwExpired = false
        ..unread = 1
        ..items = [
          AppNotification(
            id: 'b-clean',
            title: 'Recordatorio limpio de Cuenta B',
            message: 'Recargado tras expiración previa.',
            type: AppNotificationType.reminder,
            createdAt: DateTime(2026, 11, 22, 13),
          ),
        ];

      final router = _buildSwitchAccountRouter(
        authService: _FakeAuthService(),
        initialLocation: '/app',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        NotificationsScope(
          notifier: viewModel,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(viewModel.sessionExpired, isFalse);
      expect(viewModel.unreadCount, 1);
      expect(find.text('1'), findsOneWidget);

      // Ahora fuerza nuevamente sessionExpired antes de abrir NotificationsPage.
      repository.throwExpired = true;
      await viewModel.load();
      expect(viewModel.sessionExpired, isTrue);
      repository.throwExpired = false;

      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Recordatorio limpio de Cuenta B'), findsOneWidget);
      expect(find.text('No pudimos cargar tus notificaciones'), findsNothing);
      expect(viewModel.sessionExpired, isFalse);
      expect(viewModel.unreadCount, 1);
    },
  );

  testWidgets(
    'LoginPage con Google y RegisterPage limpian NotificationsScope al montar y antes de navegar a /app',
    (tester) async {
      final storage = _MutableStorage(null);
      final previousStorage = appSessionStorage;
      appSessionStorage = storage;
      addTearDown(() => appSessionStorage = previousStorage);

      final viewModel = NotificationsViewModel(initialNotifications: _seed());
      addTearDown(viewModel.dispose);

      final authService = _FakeAuthService(
        onGoogleLogin: () => storage.accessToken = 'token-b-google',
        onRegister: () => storage.accessToken = 'token-b-register',
      );

      final loginRouter = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => LoginPage(authService: authService),
          ),
          GoRoute(
            path: '/app',
            builder: (context, state) => const Scaffold(body: Text('APP_HOME')),
          ),
        ],
      );
      addTearDown(loginRouter.dispose);

      await tester.pumpWidget(
        NotificationsScope(
          notifier: viewModel,
          child: MaterialApp.router(routerConfig: loginRouter),
        ),
      );
      await tester.pumpAndSettle();

      // Al montar LoginPage se limpian los avisos previos.
      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);

      // Si quedara estado sucio tras montar (p. ej. una carga tardía), también se
      // limpia justo antes de navegar a /app con Google.
      await viewModel.load();
      expect(viewModel.notifications, hasLength(1));

      final googleBtn = find.text('Continuar con Google');
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(find.text('APP_HOME'), findsOneWidget);
      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);

      // RegisterPage: limpia al montar y antes de navegar a /app tras registro.
      final registerVm = NotificationsViewModel(initialNotifications: _seed());
      addTearDown(registerVm.dispose);
      final registerRouter = GoRouter(
        initialLocation: '/register',
        routes: [
          GoRoute(
            path: '/register',
            builder: (context, state) => RegisterPage(authService: authService),
          ),
          GoRoute(
            path: '/app',
            builder: (context, state) => const Scaffold(body: Text('APP_HOME')),
          ),
        ],
      );
      addTearDown(registerRouter.dispose);

      await tester.pumpWidget(
        NotificationsScope(
          notifier: registerVm,
          child: MaterialApp.router(routerConfig: registerRouter),
        ),
      );
      await tester.pumpAndSettle();

      expect(registerVm.notifications, isEmpty);
      expect(registerVm.unreadCount, 0);

      await registerVm.load();
      expect(registerVm.notifications, hasLength(1));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Cuenta B');
      await tester.enterText(fields.at(1), 'cuenta_b');
      await tester.enterText(fields.at(2), 'cuenta.b@test.com');
      await tester.enterText(fields.at(3), 'Password123!');
      await tester.enterText(fields.at(4), 'Password123!');
      final privacy = find.text(
        'He leído el aviso de privacidad y acepto el tratamiento de mis '
        'datos personales descrito en él.',
      );
      await tester.ensureVisible(privacy);
      await tester.tap(privacy);
      await tester.pumpAndSettle();

      final registerBtn = find.text('Crear cuenta').last;
      await tester.ensureVisible(registerBtn);
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      expect(find.text('APP_HOME'), findsOneWidget);
      expect(registerVm.notifications, isEmpty);
      expect(registerVm.unreadCount, 0);
    },
  );
}
