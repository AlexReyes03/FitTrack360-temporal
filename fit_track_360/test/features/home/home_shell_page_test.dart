import 'dart:async';
import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/network/connectivity_service.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/home/presentation/home_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
  Future<String?> readAccessToken() async => accessToken;

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

http.Response _profile() => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'id': '1',
      'email': 'ana@test.com',
      'username': 'ana',
      'displayName': 'Ana',
      'createdAt': '2026-11-04T00:00:00.000Z',
    }),
  ),
  200,
);

Future<void> _pumpShell(
  WidgetTester tester, {
  required FakeConnectivityService connectivity,
  required FakeSessionStorage storage,
  required http.Client client,
}) async {
  final router = GoRouter(
    initialLocation: '/app',
    routes: [
      GoRoute(
        path: '/app',
        builder: (context, state) => HomeShellPage(
          apiClient: ApiClient(storage: storage, httpClient: client),
          sessionStorage: storage,
          connectivityService: connectivity,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Text('Pantalla login'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
}

void main() {
  late FakeSessionStorage storage;

  setUp(() => storage = FakeSessionStorage());

  testWidgets('con red no muestra el banner y carga el perfil', (tester) async {
    await _pumpShell(
      tester,
      connectivity: FakeConnectivityService(online: true),
      storage: storage,
      client: MockClient((_) async => _profile()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsNothing);
    expect(find.text('Hola, Ana'), findsOneWidget);
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
      client: MockClient((_) async {
        if (offline) throw http.ClientException('sin red');
        return _profile();
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
    expect(requests, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no lanza dos cargas de perfil simultaneas', (tester) async {
    var requests = 0;
    final pending = Completer<http.Response>();
    final connectivity = FakeConnectivityService(online: true);
    await _pumpShell(
      tester,
      connectivity: connectivity,
      storage: storage,
      client: MockClient((_) {
        requests++;
        return pending.future;
      }),
    );
    await tester.pump();
    expect(requests, 1);

    connectivity.emit(true);
    await tester.pump();
    expect(requests, 1);

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

    await tester.tap(find.text('Cerrar sesion'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla login'), findsOneWidget);
    expect(storage.accessToken, isNull);
    expect(tester.takeException(), isNull);
  });
}
