import 'dart:convert';
import 'dart:io';

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

  test('sube a POST /api/v1/photos y parsea metadata', () async {
    late http.BaseRequest captured;
    final temp = File(
      '${Directory.systemTemp.path}/ft360-photo-upload-test.jpg',
    );
    await temp.writeAsBytes(transparentImage);

    final api = _api(
      MockClient((request) async {
        captured = request;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/photos');
        expect(
          request.headers['content-type'] ?? '',
          contains('multipart/form-data'),
        );
        // La parte `file` declara el formato real (PNG), no octet-stream:
        // el API responde 400 si no coincide.
        final body = String.fromCharCodes(request.bodyBytes).toLowerCase();
        expect(body, contains('content-type: image/png'));
        expect(body, isNot(contains('application/octet-stream')));
        return http.Response(
          jsonEncode({
            'id': 'ph-1',
            'mimeType': 'image/jpeg',
            'sizeBytes': 12,
            'width': 1,
            'height': 1,
            'mealId': null,
            'metricId': null,
            'createdAt': '2026-11-19T12:00:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final meta = await api.upload(temp);

    expect(captured.url.path, '/api/v1/photos');
    expect(meta.id, 'ph-1');
    expect(meta.mimeType, 'image/jpeg');

    await temp.delete();
  });

  test('upload con metricId envía el campo multipart', () async {
    String? bodyText;
    final temp = File(
      '${Directory.systemTemp.path}/ft360-photo-metric-test.jpg',
    );
    await temp.writeAsBytes(transparentImage);

    final api = _api(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/photos');
        // MockClient materializa MultipartRequest como Request (bytes binarios).
        bodyText = String.fromCharCodes(request.bodyBytes);
        return http.Response(
          jsonEncode({
            'id': 'ph-2',
            'mimeType': 'image/jpeg',
            'sizeBytes': 12,
            'width': 1,
            'height': 1,
            'mealId': null,
            'metricId': 'metric-9',
            'createdAt': '2026-11-19T12:00:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await api.upload(temp, metricId: 'metric-9');

    expect(bodyText, contains('metric-9'));
    await temp.delete();
  });

  test('delete 404 se trata como foto no disponible', () async {
    final api = _api(
      MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/photos/ajena');
        return http.Response('{"message":"Foto no encontrada"}', 404);
      }),
    );

    expect(
      () => api.delete('ajena'),
      throwsA(isA<ProgressPhotoUnavailableException>()),
    );
  });

  test('delete 204 completa sin error', () async {
    final api = _api(MockClient((request) async => http.Response('', 204)));

    await api.delete('ph-1');
  });

  test('metricId y mealId juntos lanzan error de validación de foto', () async {
    final api = _api(MockClient((request) async => fail('no debe llamar')));

    expect(
      () => api.upload(File('x.jpg'), metricId: 'm', mealId: 'c'),
      throwsA(isA<ProgressPhotoValidationException>()),
    );
  });

  test('un 400 del API se reporta como validación de foto', () async {
    final temp = File('${Directory.systemTemp.path}/ft360-photo-400.jpg');
    await temp.writeAsBytes(transparentImage);
    final api = _api(
      MockClient(
        (request) async => http.Response(
          '{"message":"Imagen inválida o formato no admitido"}',
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.upload(temp),
      throwsA(
        isA<ProgressPhotoValidationException>().having(
          (e) => e.message,
          'message',
          'Imagen inválida o formato no admitido',
        ),
      ),
    );
    await temp.delete();
  });

  test('un 500 al subir lanza ProgressPhotoUploadException', () async {
    final temp = File('${Directory.systemTemp.path}/ft360-photo-500.jpg');
    await temp.writeAsBytes(transparentImage);
    final api = _api(MockClient((request) async => http.Response('', 500)));

    await expectLater(
      api.upload(temp),
      throwsA(isA<ProgressPhotoUploadException>()),
    );
    await temp.delete();
  });
}
