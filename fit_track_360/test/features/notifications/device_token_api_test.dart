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

  test('revoca con POST /notifications/devices/revoke', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    await api.revokeDeviceToken(token: 'tok-1');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/notifications/devices/revoke');
    expect(jsonDecode(captured.body), {'token': 'tok-1'});
  });

  test('si revoke responde 404 intenta DELETE del token', () async {
    final methods = <String>[];
    final paths = <String>[];
    final api = _api(
      MockClient((request) async {
        methods.add(request.method);
        paths.add(request.url.path);
        if (request.method == 'POST') return http.Response('', 404);
        return http.Response('', 204);
      }),
    );

    await api.revokeDeviceToken(token: 'tok-1');

    expect(methods, ['POST', 'DELETE']);
    expect(paths, [
      '/api/v1/notifications/devices/revoke',
      '/api/v1/notifications/devices/tok-1',
    ]);
  });

  test('si revoke responde 405 intenta DELETE del token', () async {
    final methods = <String>[];
    final api = _api(
      MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'POST') return http.Response('', 405);
        return http.Response('', 200);
      }),
    );

    await api.revokeDeviceToken(token: 'tok-1');

    expect(methods, ['POST', 'DELETE']);
  });

  test('si POST y DELETE responden 404 concluye en silencio', () async {
    final api = _api(MockClient((request) async => http.Response('', 404)));

    await api.revokeDeviceToken(token: 'ajena');
  });

  test('codifica el token al usar DELETE', () async {
    late http.Request fallback;
    final api = _api(
      MockClient((request) async {
        if (request.method == 'POST') return http.Response('', 404);
        fallback = request;
        return http.Response('', 204);
      }),
    );

    await api.revokeDeviceToken(token: 'tok:1/abc');

    expect(fallback.url.toString(), contains('tok%3A1%2Fabc'));
  });

  test('un error final al revocar lanza DeviceTokenApiException', () async {
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
        isA<DeviceTokenApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });
}
