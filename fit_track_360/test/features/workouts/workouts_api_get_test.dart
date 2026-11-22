import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_not_found_exception.dart';
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

void main() {
  test('getById lanza WorkoutNotFoundException ante un 404', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'message': 'Workout not found'})),
        404,
      ),
    );
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));

    expect(
      () => api.getById('ajena'),
      throwsA(isA<WorkoutNotFoundException>()),
    );
  });

  test('getById conserva el error del API para otros estados', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'message': 'Fallo interno'})),
        500,
      ),
    );
    final api = WorkoutsApi(ApiClient(storage: _Storage(), httpClient: client));

    expect(
      () => api.getById('actual'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          'Fallo interno',
        ),
      ),
    );
  });
}
