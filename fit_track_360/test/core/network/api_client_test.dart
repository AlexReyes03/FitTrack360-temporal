import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../features/exercises/support/exercise_test_support.dart';

void main() {
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

      await expectLater(
        client.delete('/api/v1/users/me'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(storage.accessToken, isNull);
    });
  });
}
