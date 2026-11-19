import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/progress/data/progress_photos_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/progress_test_data.dart';

class _FakeStorage implements SessionStorage {
  _FakeStorage({this.access = 'access'});

  String? access;

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

ProgressPhotosApi _api(MockClient client, {_FakeStorage? storage}) {
  return ProgressPhotosApi(
    ApiClient(storage: storage ?? _FakeStorage(), httpClient: client),
  );
}

String? _authorization(http.BaseRequest request) {
  return request.headers['Authorization'] ?? request.headers['authorization'];
}

void main() {
  test('descarga la foto con autenticación', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response.bytes(transparentImage, 200);
      }),
    );

    final bytes = await api.load('photo-1');

    expect(bytes, orderedEquals(transparentImage));
    expect(captured.url.path, '/api/v1/photos/photo-1');
    expect(_authorization(captured), 'Bearer access');
  });

  test(
    'un 404 no revela el identificador ni el mensaje del servidor',
    () async {
      final api = _api(
        MockClient(
          (request) async => http.Response(
            '{"message":"Foto no encontrada"}',
            404,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      try {
        await api.load('photo-1');
        fail('Debió lanzar ProgressPhotoUnavailableException');
      } on ProgressPhotoUnavailableException catch (error) {
        expect(error.toString(), isNot(contains('photo-1')));
        expect(error.toString(), isNot(contains('encontrada')));
      }
    },
  );

  test('un error HTTP se muestra como foto no disponible', () async {
    final api = _api(
      MockClient((request) async => http.Response('fallo interno', 500)),
    );

    expect(
      () => api.load('photo-1'),
      throwsA(isA<ProgressPhotoUnavailableException>()),
    );
  });

  test('renueva el token y reintenta tras un 401', () async {
    final authorizations = <String?>[];
    var calls = 0;
    final storage = _FakeStorage();
    final api = _api(
      MockClient((request) async {
        calls++;
        authorizations.add(_authorization(request));
        if (calls == 1) return http.Response('', 401);
        return http.Response.bytes(transparentImage, 200);
      }),
      storage: storage,
    );

    final bytes = await api.load('photo-1');

    expect(bytes, orderedEquals(transparentImage));
    expect(authorizations, ['Bearer access', 'Bearer renewed']);
  });

  test('propaga la sesión expirada cuando no puede renovar', () async {
    final storage = _FakeStorage(access: null);
    final api = _api(
      MockClient((request) async => http.Response('', 401)),
      storage: storage,
    );

    expect(() => api.load('photo-1'), throwsA(isA<SessionExpiredException>()));
  });
}
