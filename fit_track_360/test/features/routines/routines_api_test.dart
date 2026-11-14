import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/routines/data/routines_api.dart';
import 'package:fit_track_360/features/routines/data/routines_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStorage implements SessionStorage {
  @override
  Future<String?> readAccessToken() async => 'access';

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

http.Response _json(Object body, int status) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );
}

RoutinesApi _api(MockClient client) {
  return RoutinesApi(ApiClient(storage: _FakeStorage(), httpClient: client));
}

void main() {
  test('lista las rutinas desde /api/v1/routines', () async {
    Uri? requested;
    final api = _api(
      MockClient((request) async {
        requested = request.url;
        return _json([
          {
            'id': 'r1',
            'name': 'Fuerza',
            'notes': 'Empuje',
            'exercises': [
              {'exerciseId': 'e1', 'targetSets': 3},
              {'exerciseId': 'e2', 'targetSets': 4},
            ],
          },
        ], 200);
      }),
    );

    final routines = await api.list();

    expect(requested?.path, '/api/v1/routines');
    expect(routines, hasLength(1));
    expect(routines.single.exerciseCount, 2);
    expect(routines.single.targetSetCount, 7);
  });

  test(
    'acepta el sobre {items} mientras el contrato no esté confirmado',
    () async {
      final api = _api(
        MockClient((request) async {
          return _json({
            'items': [
              {'id': 'r1', 'name': 'Pierna'},
            ],
          }, 200);
        }),
      );

      final routines = await api.list();

      expect(routines.single.name, 'Pierna');
      expect(routines.single.exerciseCount, isNull);
    },
  );

  test('traduce un 404 del detalle a RoutineNotFoundException', () async {
    final api = _api(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/routines/r1');
        return _json({'message': 'No existe'}, 404);
      }),
    );

    expect(() => api.getById('r1'), throwsA(isA<RoutineNotFoundException>()));
  });

  test('ordena el detalle recibido por posición', () async {
    final api = _api(
      MockClient((request) async {
        return _json({
          'id': 'r1',
          'name': 'Full body',
          'exercises': [
            {'exerciseId': 'e2', 'position': 2, 'exerciseName': 'Press banca'},
            {'exerciseId': 'e1', 'position': 1, 'exerciseName': 'Sentadilla'},
          ],
        }, 200);
      }),
    );

    final detail = await api.getById('r1');

    expect(detail.exercises.map((item) => item.displayName), [
      'Sentadilla',
      'Press banca',
    ]);
  });

  test('propaga el mensaje de error del API', () async {
    final api = _api(
      MockClient((request) async {
        return _json({'message': 'Rutinas no disponibles'}, 500);
      }),
    );

    expect(
      () => api.list(),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          'Rutinas no disponibles',
        ),
      ),
    );
  });
}
