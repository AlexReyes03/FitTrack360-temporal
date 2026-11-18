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
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      'access';

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
            'userId': 'u1',
            'name': 'Fuerza',
            'createdAt': '2026-11-16T12:00:00.000Z',
            'exercises': [
              {
                'id': 're1',
                'routineId': 'r1',
                'exerciseId': 'e1',
                'position': 1,
                'targetSets': 3,
                'targetReps': 10,
              },
              {
                'id': 're2',
                'routineId': 'r1',
                'exerciseId': 'e2',
                'position': 2,
                'targetSets': 4,
                'targetReps': 8,
              },
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
    expect(routines.single.notes, isNull);
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

  test(
    'resuelve nombres desde el catálogo con la forma real del API',
    () async {
      final paths = <String>[];
      final api = _api(
        MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/api/v1/routines/r1') {
            return _json({
              'id': 'r1',
              'userId': 'u1',
              'name': 'Full body',
              'exercises': [
                {
                  'id': 're2',
                  'routineId': 'r1',
                  'exerciseId': 'e2',
                  'position': 2,
                  'targetSets': 3,
                  'targetReps': 10,
                },
                {
                  'id': 're1',
                  'routineId': 'r1',
                  'exerciseId': 'e1',
                  'position': 1,
                  'targetSets': 4,
                  'targetReps': 8,
                },
              ],
            }, 200);
          }
          if (request.url.path == '/api/v1/exercises/e1') {
            return _json({
              'id': 'e1',
              'name': 'Squat',
              'nameEs': 'Sentadilla',
            }, 200);
          }
          if (request.url.path == '/api/v1/exercises/e2') {
            return _json({'id': 'e2', 'name': 'Bench press'}, 200);
          }
          return _json({'message': 'No existe'}, 404);
        }),
      );

      final detail = await api.getById('r1');

      expect(detail.exercises.map((item) => item.displayName), [
        'Sentadilla',
        'Bench press',
      ]);
      expect(detail.exercises.map((item) => item.targetLabel), [
        '4 series × 8 reps',
        '3 series × 10 reps',
      ]);
      expect(
        paths,
        containsAll([
          '/api/v1/routines/r1',
          '/api/v1/exercises/e1',
          '/api/v1/exercises/e2',
        ]),
      );
      expect(
        paths.where((path) => path == '/api/v1/exercises/e1'),
        hasLength(1),
      );
    },
  );

  test('conserva el detalle si el catálogo no responde', () async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/api/v1/routines/r1') {
          return _json({
            'id': 'r1',
            'name': 'Full body',
            'exercises': [
              {
                'exerciseId': 'e1',
                'position': 1,
                'targetSets': 3,
                'targetReps': 12,
              },
            ],
          }, 200);
        }
        return _json({'message': 'Error interno'}, 500);
      }),
    );

    final detail = await api.getById('r1');

    expect(detail.exercises.single.displayName, 'Ejercicio');
    expect(detail.exercises.single.targetLabel, '3 series × 12 reps');
  });

  test('no consulta el catálogo si la rutina ya trae el nombre', () async {
    var requests = 0;
    final api = _api(
      MockClient((request) async {
        requests++;
        expect(request.url.path, '/api/v1/routines/r1');
        return _json({
          'id': 'r1',
          'name': 'Full body',
          'exercises': [
            {
              'exerciseId': 'e1',
              'exerciseName': 'Sentadilla',
              'position': 1,
              'targetSets': 4,
              'targetReps': 8,
            },
          ],
        }, 200);
      }),
    );

    final detail = await api.getById('r1');

    expect(detail.exercises.single.displayName, 'Sentadilla');
    expect(requests, 1);
  });

  test('propaga la sesión expirada del catálogo', () async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/api/v1/routines/r1') {
          return _json({
            'id': 'r1',
            'name': 'Full body',
            'exercises': [
              {'exerciseId': 'e1', 'position': 1, 'targetSets': 3},
            ],
          }, 200);
        }
        return _json({'message': 'No autorizado'}, 401);
      }),
    );

    expect(() => api.getById('r1'), throwsA(isA<SessionExpiredException>()));
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
