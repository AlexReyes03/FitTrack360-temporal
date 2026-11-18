import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/logout_service.dart';
import 'package:fit_track_360/features/settings/data/profile_api_repository.dart';
import 'package:fit_track_360/features/settings/domain/profile_repository.dart';
import 'package:fit_track_360/features/settings/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  group('ProfileApiRepository', () {
    test('PATCH parcial y luego GET recupera nombre y metas', () async {
      final server = sampleProfileJson();
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/users/me' &&
            request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['displayName'] != null) {
            server['displayName'] = body['displayName'];
          }
          if (body['goals'] != null) server['goals'] = body['goals'];
          return _json(server);
        }
        if (request.url.path == '/api/v1/users/me') return _json(server);
        return http.Response('', 404);
      });
      final repo = ProfileApiRepository(
        ApiClient(storage: FakeSessionStorage(), httpClient: client),
      );

      await repo.updateProfile(
        const ProfileUpdate(
          displayName: 'Bea',
          goals: NutritionGoals(
            dailyCalorieGoal: 1800,
            proteinGoalG: 120,
            carbsGoalG: 200,
            fatGoalG: 60,
          ),
        ),
      );
      final again = await repo.fetchProfile();

      expect(requests.first.method, 'PATCH');
      expect(requests.first.headers['Authorization'], 'Bearer access');
      expect(jsonDecode(requests.first.body), {
        'displayName': 'Bea',
        'goals': {
          'dailyCalorieGoal': 1800,
          'proteinGoalG': 120,
          'carbsGoalG': 200,
          'fatGoalG': 60,
        },
      });
      expect(again!.displayName, 'Bea');
      expect(again.goals.dailyCalorieGoal, 1800);
    });

    test(
      'el contador viene en workoutCount de /users/me sin pedir /workouts',
      () async {
        final requests = <String>[];
        final client = MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path.contains('/workouts')) {
            fail('El contador no debe descargar el historial: ${request.url}');
          }
          return _json({...sampleProfileJson(), 'workoutCount': 2});
        });
        final repo = ProfileApiRepository(
          ApiClient(storage: FakeSessionStorage(), httpClient: client),
        );

        final profile = await repo.fetchProfile();

        expect(profile!.workoutCount, 2);
        expect(requests, ['/api/v1/users/me']);
      },
    );

    test('un /users/me sin workoutCount deja el contador en null', () async {
      final json = sampleProfileJson()..remove('workoutCount');
      final client = MockClient((_) async => _json(json));
      final repo = ProfileApiRepository(
        ApiClient(storage: FakeSessionStorage(), httpClient: client),
      );
      expect((await repo.fetchProfile())!.workoutCount, isNull);
    });

    test('exportData devuelve el JSON si el endpoint responde 200', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/users/me/export');
        return _json({'profile': {}});
      });
      final repo = ProfileApiRepository(
        ApiClient(storage: FakeSessionStorage(), httpClient: client),
      );
      final exported = await repo.exportData();
      expect(jsonDecode(exported), {'profile': {}});
      expect(exported, contains('\n  '));
    });

    test('exportData 404 o fallo de red lanza ExportUnavailable', () async {
      for (final client in [
        MockClient((_) async => http.Response('Not Found', 404)),
        MockClient((_) async => throw http.ClientException('sin red')),
      ]) {
        final repo = ProfileApiRepository(
          ApiClient(storage: FakeSessionStorage(), httpClient: client),
        );
        await expectLater(
          repo.exportData(),
          throwsA(isA<ExportUnavailableException>()),
        );
      }
    });
  });

  group('LogoutService', () {
    test('revoca el ID token y limpia la sesión', () async {
      final storage = FakeSessionStorage();
      String? revoked;
      await LogoutService(
        storage: storage,
        revoke: ({required idToken}) async => revoked = idToken,
      ).logout();
      expect(revoked, 'access');
      expect(storage.accessToken, isNull);
    });

    test('limpia la sesión aunque el API falle', () async {
      final storage = FakeSessionStorage();
      await LogoutService(
        storage: storage,
        revoke: ({required idToken}) async => throw Exception('sin red'),
      ).logout();
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    });
  });
}
