import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/settings/data/privacy_api_repository.dart';
import 'package:fit_track_360/features/settings/domain/privacy_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  group('PrivacyApiRepository', () {
    test('fetchNotice lee versión, fecha y secciones del API', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _json({
          'version': '2',
          'date': '2026-11-16',
          'sections': [
            {'title': 'Cuenta', 'text': 'Firebase Auth gestiona el acceso.'},
            {'title': 'Salud', 'text': 'No sustituye la atención médica.'},
          ],
        });
      });
      final repo = PrivacyApiRepository(
        ApiClient(storage: FakeSessionStorage(), httpClient: client),
      );

      final notice = await repo.fetchNotice();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/privacy/notice');
      expect(notice.version, '2');
      expect(notice.date, DateTime(2026, 11, 16));
      expect(notice.sections.map((section) => section.title), [
        'Cuenta',
        'Salud',
      ]);
      expect(notice.includesMedicalLimit, isTrue);
    });

    test('fetchNotice con error HTTP no devuelve un aviso vacío', () async {
      final repo = PrivacyApiRepository(
        ApiClient(
          storage: FakeSessionStorage(),
          httpClient: MockClient((_) async => http.Response('Sin aviso', 503)),
        ),
      );

      await expectLater(repo.fetchNotice(), throwsA(isA<AuthApiException>()));
    });

    test('fetchNotice con fecha inválida falla en vez de inventarla', () async {
      final repo = PrivacyApiRepository(
        ApiClient(
          storage: FakeSessionStorage(),
          httpClient: MockClient(
            (_) async =>
                _json({'version': '2', 'date': 'ayer', 'sections': <Object>[]}),
          ),
        ),
      );

      await expectLater(repo.fetchNotice(), throwsA(isA<FormatException>()));
    });

    test('registerConsent envía usuario, versión y consentimiento', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _json({
          'privacyConsentAt': '2026-11-18T10:00:00.000Z',
          'privacyNoticeVersion': '2',
        }, 201);
      });
      final repo = PrivacyApiRepository(
        ApiClient(storage: FakeSessionStorage(), httpClient: client),
      );

      final receipt = await repo.registerConsent(userId: 'u1', version: '2');

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/v1/privacy/u1/consent');
      expect(requests.single.headers['Authorization'], 'Bearer access');
      expect(jsonDecode(requests.single.body), {
        'consent': true,
        'version': '2',
      });
      expect(receipt.version, '2');
    });

    test('registerConsent rechaza una versión no confirmada', () async {
      final repo = PrivacyApiRepository(
        ApiClient(
          storage: FakeSessionStorage(),
          httpClient: MockClient(
            (_) async => _json({'privacyNoticeVersion': '3'}, 201),
          ),
        ),
      );

      await expectLater(
        repo.registerConsent(userId: 'u1', version: '2'),
        throwsA(isA<ConsentRejectedException>()),
      );
    });

    test('registerConsent propaga el rechazo del API', () async {
      final repo = PrivacyApiRepository(
        ApiClient(
          storage: FakeSessionStorage(),
          httpClient: MockClient(
            (_) async => _json({'message': 'Usuario no encontrado'}, 404),
          ),
        ),
      );

      await expectLater(
        repo.registerConsent(userId: 'u1', version: '2'),
        throwsA(isA<AuthApiException>()),
      );
    });
  });
}
