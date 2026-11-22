import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../features/exercises/support/exercise_test_support.dart';

class _RefreshStorage implements SessionStorage {
  String? access = 'access';

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      access = access == null ? null : 'renewed';
    }
    return access;
  }

  @override
  Future<String?> readRefreshToken() async => 'refresh';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {
    access = null;
  }
}

void main() {
  test('GET, POST, PATCH y DELETE usan el metodo HTTP correcto', () async {
    final methods = <String>[];
    final client = ApiClient(
      storage: _RefreshStorage(),
      httpClient: MockClient((request) async {
        methods.add(request.method);
        expect(request.headers['Authorization'], 'Bearer access');
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);

    await client.get('/api/v1/ping');
    await client.post('/api/v1/ping', body: {'ok': true});
    await client.patch('/api/v1/ping', body: {'ok': true});
    await client.delete('/api/v1/ping');

    expect(methods, ['GET', 'POST', 'PATCH', 'DELETE']);
  });

  test('renueva el token y reintenta GET/POST/PATCH/DELETE tras 401', () async {
    final authorizations = <String?>[];
    final methods = <String>[];
    var calls = 0;
    final storage = _RefreshStorage();
    final client = ApiClient(
      storage: storage,
      httpClient: MockClient((request) async {
        calls++;
        methods.add(request.method);
        authorizations.add(request.headers['Authorization']);
        if (calls.isOdd) return http.Response('', 401);
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);

    await client.get('/api/v1/a');
    storage.access = 'access';
    await client.post('/api/v1/b', body: {'x': 1});
    storage.access = 'access';
    await client.patch('/api/v1/c', body: {'x': 1});
    storage.access = 'access';
    await client.delete('/api/v1/d');

    expect(methods, [
      'GET',
      'GET',
      'POST',
      'POST',
      'PATCH',
      'PATCH',
      'DELETE',
      'DELETE',
    ]);
    expect(authorizations, [
      'Bearer access',
      'Bearer renewed',
      'Bearer access',
      'Bearer renewed',
      'Bearer access',
      'Bearer renewed',
      'Bearer access',
      'Bearer renewed',
    ]);
  });

  group('ApiClient.delete', () {
    test('envia DELETE con Bearer y sin cuerpo a la ruta indicada', () async {
      late http.Request captured;
      final client = ApiClient(
        storage: FakeSessionStorage(accessToken: 'token-1'),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );
      addTearDown(client.dispose);

      final response = await client.delete('/api/v1/progress/photos/p1');

      expect(response.statusCode, 204);
      expect(captured.method, 'DELETE');
      expect(captured.url.toString(), '$apiBaseUrl/api/v1/progress/photos/p1');
      expect(captured.headers['Authorization'], 'Bearer token-1');
      expect(captured.body, isEmpty);
    });

    test('ante 401 renueva el token y reintenta el DELETE una vez', () async {
      final tokens = <String?>[];
      final client = ApiClient(
        storage: FakeSessionStorage(accessToken: 'renovado'),
        httpClient: MockClient((request) async {
          tokens.add(request.headers['Authorization']);
          return tokens.length == 1
              ? http.Response('', 401)
              : http.Response('', 204);
        }),
      );
      addTearDown(client.dispose);

      final response = await client.delete('/api/v1/users/me');

      expect(response.statusCode, 204);
      expect(tokens, hasLength(2));
    });

    test('si el reintento vuelve a dar 401 limpia la sesion', () async {
      final storage = FakeSessionStorage(accessToken: 'caducado');
      final client = ApiClient(
        storage: storage,
        httpClient: MockClient((_) async => http.Response('', 401)),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.delete('/api/v1/users/me'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(storage.accessToken, isNull);
    });
  });
}
