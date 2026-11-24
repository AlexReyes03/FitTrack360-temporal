import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/notifications/data/device_token_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStorage implements SessionStorage {
  String? access = 'access';

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) access = access == null ? null : 'renewed';
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

DeviceTokenApi _api(MockClient client, {_FakeStorage? storage}) {
  return DeviceTokenApi(
    ApiClient(storage: storage ?? _FakeStorage(), httpClient: client),
  );
}

void main() {
  test('registra el token con POST /notifications/devices', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response('', 201);
      }),
    );

    await api.registerDeviceToken(token: 'tok-1', platform: 'android');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/notifications/devices');
    expect(jsonDecode(captured.body), {
      'token': 'tok-1',
      'platform': 'android',
    });
  });

  test('registro acepta 200 y 204', () async {
    for (final status in [200, 204]) {
      final api = _api(
        MockClient((request) async => http.Response('', status)),
      );
      await api.registerDeviceToken(token: 'tok-1', platform: 'ios');
    }
  });

  test('un error al registrar lanza DeviceTokenApiException', () async {
    final api = _api(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'token inválido'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.registerDeviceToken(token: 'tok-1', platform: 'android'),
      throwsA(
        isA<DeviceTokenApiException>()
            .having((error) => error.message, 'message', 'token inválido')
            .having((error) => error.statusCode, 'statusCode', 400),
      ),
    );
  });

  test('revoca solo con POST /devices/revoke y el token en el body', () async {
    final requests = <http.Request>[];
    final api = _api(
      MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );

    await api.revokeDeviceToken(token: 'tok-1');

    expect(requests, hasLength(1));
    final captured = requests.single;
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/notifications/devices/revoke');
    expect(jsonDecode(captured.body), {'token': 'tok-1'});
    expect(captured.url.toString(), isNot(contains('tok-1')));
  });

  test('revoke acepta 200, 201 y 204', () async {
    for (final status in [200, 201, 204]) {
      final api = _api(
        MockClient((request) async => http.Response('', status)),
      );
      await api.revokeDeviceToken(token: 'tok-1');
    }
  });

  test('un 404 de revoke es éxito y no intenta DELETE con el token', () async {
    final requests = <http.Request>[];
    final api = _api(
      MockClient((request) async {
        requests.add(request);
        return http.Response('', 404);
      }),
    );

    await api.revokeDeviceToken(token: 'ajena');

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/notifications/devices/revoke');
    expect(requests.any((request) => request.method == 'DELETE'), isFalse);
  });

  test('un 401 al revocar lanza SessionExpiredException', () async {
    final api = _api(MockClient((request) async => http.Response('', 401)));

    await expectLater(
      api.revokeDeviceToken(token: 'tok-1'),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test('un 500 al revocar lanza DeviceTokenApiException', () async {
    final api = _api(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'fallo interno'}),
          500,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.revokeDeviceToken(token: 'tok-1'),
      throwsA(
        isA<DeviceTokenApiException>()
            .having((error) => error.message, 'message', 'fallo interno')
            .having((error) => error.statusCode, 'statusCode', 500),
      ),
    );
  });
}
