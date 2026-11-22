import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage implements SessionStorage {
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

final _created = {
  'id': 'nueva',
  'userId': 'u1',
  'routineId': 'rutina-1',
  'startedAt': '2026-11-10T18:00:00.000Z',
  'endedAt': null,
  'notes': null,
  'createdAt': '2026-11-10T18:00:00.000Z',
  'updatedAt': '2026-11-10T18:00:00.000Z',
};

void main() {
  final draft = WorkoutSessionDraft(
    routineId: 'rutina-1',
    routineName: 'Pierna',
    startedAt: DateTime.utc(2026, 11, 10, 18),
    exercises: const [
      PlannedExercise(
        exerciseId: '0001',
        exerciseName: 'Sentadilla',
        position: 1,
        targetSets: 2,
        targetReps: 8,
      ),
    ],
  );

  test('create envía a POST /workouts el payload del borrador', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(utf8.encode(jsonEncode(_created)), 201);
    });
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));

    final session = await api.create(draft);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/v1/workouts');
    expect(jsonDecode(sent.body), {
      'routineId': 'rutina-1',
      'startedAt': '2026-11-10T18:00:00.000Z',
      'sets': [
        {'exerciseId': '0001', 'order': 1, 'weight': 0, 'reps': 8},
        {'exerciseId': '0001', 'order': 2, 'weight': 0, 'reps': 8},
      ],
    });
    expect(session.id, 'nueva');
  });

  test('create propaga el mensaje del API si no responde 201', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'message': 'Uno o más ejercicios no existen'})),
        400,
      ),
    );
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));

    expect(
      () => api.create(draft),
      throwsA(
        isA<AuthApiException>().having(
          (e) => e.message,
          'message',
          'Uno o más ejercicios no existen',
        ),
      ),
    );
  });
  test('update y delete llaman rutas de sesión y envían series', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return request.method == 'PATCH'
          ? http.Response.bytes(utf8.encode(jsonEncode(_created)), 200)
          : http.Response('', 204);
    });
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));
    final payload = {
      'startedAt': '2026-11-10T18:00:00.000Z',
      'sets': [
        {'exerciseId': '0001', 'order': 1, 'weight': 0, 'reps': 12},
      ],
    };
    await api.update('nueva', payload);
    await api.delete('nueva');
    expect(requests.map((r) => r.method), ['PATCH', 'DELETE']);
    expect(
      requests.every((r) => r.url.path == '/api/v1/workouts/nueva'),
      isTrue,
    );
    expect(jsonDecode(requests.first.body), payload);
  });
}
