import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/domain/exercise_reference.dart';
import 'package:fit_track_360/features/workouts/domain/tracker_location_provider.dart';
import 'package:fit_track_360/features/workouts/presentation/tracker_view_model.dart';
import 'package:fit_track_360/features/workouts/presentation/widgets/tracker_location_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage implements SessionStorage {
  String? accessToken = 'access';

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {
    accessToken = null;
  }
}

class _FakeLocation implements TrackerLocationProvider {
  _FakeLocation({this.fix});

  TrackerGpsFix? fix;

  @override
  Future<TrackerGpsFix?> getApproximateLocation() async => fix;
}

WorkoutsApi _api(MockClient client, {SessionStorage? storage}) =>
    WorkoutsApi(ApiClient(storage: storage ?? _Storage(), httpClient: client));

Map<String, dynamic> _sessionJson({
  String id = 's1',
  String exerciseId = '0001',
  bool ended = true,
}) {
  return {
    'id': id,
    'userId': 'u1',
    'startedAt': '2026-11-10T10:00:00.000Z',
    'endedAt': ended ? '2026-11-10T11:00:00.000Z' : null,
    'notes': null,
    'location': null,
    'createdAt': '2026-11-10T10:00:00.000Z',
    'updatedAt': '2026-11-10T11:00:00.000Z',
    'sets': [
      {
        'exerciseId': exerciseId,
        'exerciseName': 'Press',
        'order': 1,
        'weight': 60,
        'weightKg': 60,
        'reps': 10,
      },
    ],
  };
}

void main() {
  test('cronometro y descanso avanzan en estado local sin red', () {
    final vm = TrackerViewModel(
      workoutsApi: _api(MockClient((_) async => http.Response('[]', 200))),
      exerciseId: '0001',
      exerciseName: 'Press',
      locationProvider: _FakeLocation(),
      autoStartSessionTimer: true,
    );
    addTearDown(vm.dispose);

    vm.tickSessionSecond();
    vm.tickSessionSecond();
    vm.tickSessionSecond();
    expect(vm.elapsedLabel, '00:00:03');
    expect(vm.isSessionTimerRunning, isTrue);

    vm.toggleSessionTimer();
    vm.tickSessionSecond();
    expect(vm.elapsedLabel, '00:00:03');

    vm.selectRestPreset(60);
    vm.startRestTimer();
    for (var i = 0; i < 5; i++) {
      vm.tickRestSecond();
    }
    expect(vm.restRemainingLabel, '00:00:55');
    expect(vm.isRestRunning, isTrue);
  });

  test('valida series: peso vacio ok, reps invalidas y negativos fallan', () {
    final vm = TrackerViewModel(
      workoutsApi: _api(MockClient((_) async => http.Response('[]', 200))),
      exerciseId: '0001',
      exerciseName: 'Press',
      locationProvider: _FakeLocation(),
      autoStartSessionTimer: false,
      initialSetCount: 1,
    );
    addTearDown(vm.dispose);

    vm.setWeightText(0, '-1');
    expect(vm.setItems.first.hasWeightError, isTrue);
    vm.setWeightText(0, '');
    expect(vm.setItems.first.hasWeightError, isFalse);

    vm.setRepsText(0, '0');
    expect(vm.setItems.first.hasRepsError, isTrue);
    vm.setRepsText(0, '8');
    expect(vm.setItems.first.hasRepsError, isFalse);
  });

  test(
    'referencia anterior se adjunta sin bloquear si no hay historial',
    () async {
      final vm = TrackerViewModel(
        workoutsApi: _api(MockClient((_) async => http.Response('[]', 200))),
        exerciseId: '0001',
        exerciseName: 'Press',
        locationProvider: _FakeLocation(),
        autoStartSessionTimer: false,
        initialSetCount: 1,
      );
      addTearDown(vm.dispose);

      await vm.loadHistoryReferences();
      expect(vm.setItems.first.previousReference, isNull);
    },
  );

  test(
    'referencia anterior aparece cuando hay historial equivalente',
    () async {
      final vm = TrackerViewModel(
        workoutsApi: _api(
          MockClient(
            (_) async => http.Response(jsonEncode([_sessionJson()]), 200),
          ),
        ),
        exerciseId: '0001',
        exerciseName: 'Press',
        locationProvider: _FakeLocation(),
        autoStartSessionTimer: false,
        initialSetCount: 1,
        now: () => DateTime.utc(2026, 11, 12, 12),
      );
      addTearDown(vm.dispose);

      await vm.loadHistoryReferences();
      final reference = vm.setItems.first.previousReference;
      expect(reference, isA<PreviousSetReference>());
      expect(reference!.weightKg, 60);
      expect(reference.reps, 10);
    },
  );

  test('P2 degrada a zona manual si GPS falla', () async {
    final vm = TrackerViewModel(
      workoutsApi: _api(MockClient((_) async => http.Response('[]', 200))),
      exerciseId: '0001',
      exerciseName: 'Press',
      locationProvider: _FakeLocation(fix: null),
      autoStartSessionTimer: false,
    );
    addTearDown(vm.dispose);

    await vm.requestGpsLocation();
    expect(vm.locationMode, TrackerLocationMode.manualZone);
    expect(vm.gpsStatusLabel, contains('zona manual'));
  });

  test('finalizar persiste series y devuelve el id de sesion', () async {
    Map<String, dynamic>? body;
    final vm = TrackerViewModel(
      workoutsApi: _api(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('[]', 200);
          }
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              ..._sessionJson(id: 'created-1'),
              'endedAt': '2026-11-12T12:30:00.000Z',
            }),
            201,
          );
        }),
      ),
      exerciseId: '0001',
      exerciseName: 'Press',
      locationProvider: _FakeLocation(),
      autoStartSessionTimer: false,
      initialSetCount: 2,
      now: () => DateTime.utc(2026, 11, 12, 12, 30),
    );
    addTearDown(vm.dispose);

    vm.setWeightText(0, '60');
    vm.setRepsText(0, '10');
    vm.setWeightText(1, '');
    vm.setRepsText(1, '12');
    vm.updateManualZone('Gimnasio Norte');
    vm.setLocationMode(TrackerLocationMode.manualZone);

    final id = await vm.finishSession();
    expect(id, 'created-1');
    expect(body?['location'], 'Gimnasio Norte');
    expect(body?['sets'], hasLength(2));
    expect(body?['sets'][1]['weight'], 0);
    expect(body?['sets'][1]['reps'], 12);
    expect(body?['endedAt'], isNotNull);
  });
}
