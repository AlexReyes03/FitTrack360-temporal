import 'dart:convert';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/exercises/data/exercise.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/data/workouts_repository_impl.dart';
import 'package:fit_track_360/features/workouts/domain/exercise_reference.dart';
import 'package:fit_track_360/features/workouts/domain/tracker_location_provider.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/presentation/tracker_view_model.dart';
import 'package:fit_track_360/features/workouts/presentation/widgets/tracker_location_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fake_workouts_repository.dart';

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

ApiWorkoutsRepository _api(MockClient client, {SessionStorage? storage}) =>
    ApiWorkoutsRepository(
      WorkoutsApi(
        ApiClient(storage: storage ?? _Storage(), httpClient: client),
      ),
    );

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
      repository: _api(MockClient((_) async => http.Response('[]', 200))),
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
      repository: _api(MockClient((_) async => http.Response('[]', 200))),
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
        repository: _api(MockClient((_) async => http.Response('[]', 200))),
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
        repository: _api(
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
      repository: _api(MockClient((_) async => http.Response('[]', 200))),
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
      repository: _api(
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
    vm.toggleSetCompleted(0);
    vm.toggleSetCompleted(1);
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

  group('series: agregar y quitar', () {
    test('agregar numera en orden y quitar renumera desde 1', () {
      final vm = _fakeVm(initialSetCount: 2);
      addTearDown(vm.dispose);

      vm.addSet();
      expect(vm.setItems.map((s) => s.order), [1, 2, 3]);

      vm.removeSet(0);
      expect(vm.setItems.map((s) => s.order), [1, 2]);
    });

    test('nunca deja la sesion con menos de una serie', () {
      final vm = _fakeVm(initialSetCount: 1);
      addTearDown(vm.dispose);

      vm.removeSet(0);
      expect(vm.setItems, hasLength(1));
      expect(vm.setItems.single.order, 1);
    });
  });

  group('validacion de peso y repeticiones', () {
    test('rechaza reps no numericas, decimales y fuera de 1..1000', () {
      final vm = _fakeVm(initialSetCount: 1);
      addTearDown(vm.dispose);

      for (final raw in ['abc', '8.5', '8,5', '0', '1001', 'NaN']) {
        vm.setRepsText(0, raw);
        expect(vm.setItems.first.hasRepsError, isTrue, reason: raw);
        expect(vm.setItems.first.errorText, isNotNull, reason: raw);
      }
      for (final raw in ['1', '1000']) {
        vm.setRepsText(0, raw);
        expect(vm.setItems.first.hasRepsError, isFalse, reason: raw);
      }
    });

    test('rechaza peso Infinity, NaN, negativo o mayor a 1000 kg', () {
      final vm = _fakeVm(initialSetCount: 1);
      addTearDown(vm.dispose);

      for (final raw in ['Infinity', '-Infinity', 'NaN', '-1', '1000.5']) {
        vm.setWeightText(0, raw);
        expect(vm.setItems.first.hasWeightError, isTrue, reason: raw);
        expect(vm.setItems.first.errorText, isNotNull, reason: raw);
      }
      for (final raw in ['0', '62,5', '1000']) {
        vm.setWeightText(0, raw);
        expect(vm.setItems.first.hasWeightError, isFalse, reason: raw);
      }
    });

    test('aumentar o disminuir peso desde Infinity no lanza', () {
      final vm = _fakeVm(initialSetCount: 1);
      addTearDown(vm.dispose);

      vm.setWeightText(0, 'Infinity');
      vm.incrementWeight(0);
      expect(vm.setItems.first.weightText, '2.5');
      vm.setWeightText(0, 'Infinity');
      vm.decrementWeight(0);
      expect(vm.setItems.first.weightText, '');
    });

    test('no permite completar una serie con peso Infinity', () {
      final vm = _fakeVm(initialSetCount: 1);
      addTearDown(vm.dispose);

      vm.setWeightText(0, 'Infinity');
      vm.setRepsText(0, '10');
      vm.toggleSetCompleted(0);
      expect(vm.setItems.first.completed, isFalse);
    });
  });

  group('finalizar sesion', () {
    test(
      'sin series completadas bloquea con mensaje y no envia nada',
      () async {
        final repo = FakeWorkoutsRepository(sessions: const []);
        final vm = _fakeVm(repository: repo, initialSetCount: 2);
        addTearDown(vm.dispose);

        vm.setWeightText(0, '60');
        vm.setRepsText(0, '10');

        final id = await vm.finishSession();
        expect(id, isNull);
        expect(repo.createdPayloads, isEmpty);
        expect(vm.finishError, 'Completa al menos una serie');
      },
    );

    test('serie completada invalida no envia nada y muestra error', () async {
      final repo = FakeWorkoutsRepository(sessions: const []);
      final vm = _fakeVm(repository: repo, initialSetCount: 1);
      addTearDown(vm.dispose);

      vm.setWeightText(0, '60');
      vm.setRepsText(0, '10');
      vm.toggleSetCompleted(0);
      vm.setWeightText(0, 'Infinity');

      final id = await vm.finishSession();
      expect(id, isNull);
      expect(repo.createdPayloads, isEmpty);
      expect(vm.finishError, isNotNull);
      expect(vm.finishState, isA<AsyncError<String>>());
      expect(vm.setItems.first.hasWeightError, isTrue);
    });

    test(
      'solo envia series completadas con exerciseId y orden desde 1',
      () async {
        final repo = FakeWorkoutsRepository(sessions: const []);
        final vm = _fakeVm(repository: repo, initialSetCount: 3);
        addTearDown(vm.dispose);

        // Serie 1 queda pendiente y vacia: no debe bloquear ni enviarse.
        vm.setWeightText(1, '60');
        vm.setRepsText(1, '10');
        vm.toggleSetCompleted(1);
        vm.setRepsText(2, '8');
        vm.toggleSetCompleted(2);

        final id = await vm.finishSession();
        expect(id, isNotNull);
        expect(repo.createdPayloads, hasLength(1));
        final sets = repo.createdPayloads.single['sets'] as List;
        expect(sets, hasLength(2));
        expect(sets.map((s) => s['exerciseId']), ['0001', '0001']);
        expect(sets.map((s) => s['order']), [1, 2]);
        expect(sets.map((s) => s['reps']), [10, 8]);
        expect(sets.map((s) => s['weight']), [60, 0]);
      },
    );

    test('error del API deja el mensaje y estado de error', () async {
      final repo = FakeWorkoutsRepository(
        sessions: const [],
        createError: const AuthApiException('Servidor no disponible'),
      );
      final vm = _fakeVm(repository: repo, initialSetCount: 1);
      addTearDown(vm.dispose);

      vm.setRepsText(0, '10');
      vm.toggleSetCompleted(0);

      final id = await vm.finishSession();
      expect(id, isNull);
      expect(vm.finishError, 'Servidor no disponible');
      expect(vm.finishState, isA<AsyncError<String>>());
    });

    test('sesion expirada marca sessionExpired sin id', () async {
      final repo = FakeWorkoutsRepository(
        sessions: const [],
        createError: const SessionExpiredException(),
      );
      final vm = _fakeVm(repository: repo, initialSetCount: 1);
      addTearDown(vm.dispose);

      vm.setRepsText(0, '10');
      vm.toggleSetCompleted(0);

      final id = await vm.finishSession();
      expect(id, isNull);
      expect(vm.sessionExpired, isTrue);
    });
  });

  test('referencia anterior usa la posicion dentro del ejercicio, no el orden global', () async {
    final previous = fakeSession(
      id: 'previa',
      startedAt: DateTime.utc(2026, 11, 10, 10),
      sets: const [
        WorkoutSet(
          exerciseName: 'Sentadilla',
          exerciseId: '0002',
          order: 1,
          weightKg: 100,
          reps: 5,
        ),
        WorkoutSet(
          exerciseName: 'Press',
          exerciseId: '0001',
          order: 2,
          weightKg: 80,
          reps: 8,
        ),
        WorkoutSet(
          exerciseName: 'Sentadilla',
          exerciseId: '0002',
          order: 3,
          weightKg: 100,
          reps: 5,
        ),
        WorkoutSet(
          exerciseName: 'Press',
          exerciseId: '0001',
          order: 4,
          weightKg: 82.5,
          reps: 6,
        ),
      ],
    );
    final vm = _fakeVm(
      repository: FakeWorkoutsRepository(sessions: [previous]),
      initialSetCount: 3,
    );
    addTearDown(vm.dispose);

    await vm.loadHistoryReferences();
    final refs = vm.setItems.map((s) => s.previousReference).toList();
    expect(refs[0]?.weightKg, 80);
    expect(refs[0]?.reps, 8);
    expect(refs[1]?.weightKg, 82.5);
    expect(refs[1]?.reps, 6);
    expect(refs[2], isNull);
  });
  group('varios ejercicios (rutina o repetir)', () {
    final draft = WorkoutSessionDraft(
      routineId: 'rutina-1',
      startedAt: DateTime.utc(2026, 11, 12, 10),
      exercises: const [
        PlannedExercise(
          exerciseId: '0002',
          exerciseName: 'Zancada',
          position: 1,
          targetSets: 1,
          targetReps: 12,
        ),
        PlannedExercise(
          exerciseId: '0001',
          exerciseName: 'Sentadilla',
          position: 0,
          targetSets: 2,
          targetReps: 8,
        ),
      ],
    );

    TrackerViewModel planVm(FakeWorkoutsRepository repo) {
      final vm = TrackerViewModel.plan(
        repository: repo,
        locationProvider: _FakeLocation(),
        exercises: TrackerExercisePlan.listFromDraft(draft),
        routineId: draft.routineId,
        autoStartSessionTimer: false,
        now: () => DateTime.utc(2026, 11, 12, 12),
      );
      addTearDown(vm.dispose);
      return vm;
    }

    test('precarga series objetivo en el orden de la rutina', () {
      final vm = planVm(FakeWorkoutsRepository(sessions: const []));

      expect(vm.exerciseName, 'Sentadilla');
      expect(vm.exerciseData.progressLabel, 'Ejercicio 1 de 2');
      expect(vm.setItems.map((s) => s.repsText), ['8', '8']);
      expect(vm.hasPreviousExercise, isFalse);

      vm.nextExercise();
      expect(vm.exerciseName, 'Zancada');
      expect(vm.setItems.map((s) => s.repsText), ['12']);
      expect(vm.hasNextExercise, isFalse);
    });

    test('una sesión repetida precarga peso y repeticiones exactos', () {
      final repeated = WorkoutSessionDraft(
        startedAt: DateTime.utc(2026, 11, 12),
        exercises: const [
          PlannedExercise(
            exerciseId: '0001',
            exerciseName: 'Sentadilla',
            position: 0,
            targetSets: 2,
            targetReps: 5,
          ),
        ],
        sets: const [
          PlannedSet(exerciseId: '0001', order: 1, weightKg: 100, reps: 5),
          PlannedSet(exerciseId: '0001', order: 2, weightKg: 102.5, reps: 3),
        ],
      );

      final plans = TrackerExercisePlan.listFromDraft(repeated);

      expect(plans.single.sets.map((s) => [s.weightText, s.repsText]), [
        ['100', '5'],
        ['102.5', '3'],
      ]);
    });

    test(
      'finalizar envía las series de todos los ejercicios y la rutina',
      () async {
        final repo = FakeWorkoutsRepository(sessions: const []);
        final vm = planVm(repo);
        vm.setWeightText(0, '60');
        vm.toggleSetCompleted(0);
        vm.nextExercise();
        vm.toggleSetCompleted(0);

        final id = await vm.finishSession();

        expect(id, isNotNull);
        final payload = repo.createdPayloads.single;
        expect(payload['routineId'], 'rutina-1');
        expect(payload['sets'], [
          {'exerciseId': '0001', 'order': 1, 'weight': 60.0, 'reps': 8},
          {'exerciseId': '0002', 'order': 2, 'weight': 0.0, 'reps': 12},
        ]);
      },
    );

    test('un error en otro ejercicio lleva a ese ejercicio', () async {
      final vm = planVm(FakeWorkoutsRepository(sessions: const []));
      vm.toggleSetCompleted(0);
      vm.setRepsText(0, '');
      vm.nextExercise();
      vm.toggleSetCompleted(0);

      expect(await vm.finishSession(), isNull);
      expect(vm.currentExerciseIndex, 0);
      expect(vm.setItems.first.hasRepsError, isTrue);
    });

    test('cambiar de ejercicio reinicia sus series', () {
      final vm = planVm(FakeWorkoutsRepository(sessions: const []));
      vm.replaceCurrentExercise(
        const TrackerExercisePlan(exerciseId: '0009', name: 'Plancha'),
      );

      expect(vm.exerciseId, '0009');
      expect(vm.setItems, hasLength(vm.initialSetCount));
      expect(vm.setItems.every((s) => s.repsText.isEmpty), isTrue);
    });

    test('los datos del catálogo traen etiquetas en español', () {
      final vm = planVm(FakeWorkoutsRepository(sessions: const []));
      expect(vm.exerciseIdsWithoutDetails, {'0001', '0002'});

      vm.attachExerciseDetails(
        '0001',
        const Exercise(
          id: '0001',
          name: 'squat',
          bodyPart: 'upper legs',
          equipment: 'body weight',
          target: 'quads',
          attribution: 'Gym Visual',
        ),
      );

      expect(vm.exerciseName, 'Sentadilla');
      expect(vm.exerciseTags, ['Muslos', 'Cuádriceps', 'Peso corporal']);
      expect(vm.currentExercise?.id, '0001');
      expect(vm.exerciseIdsWithoutDetails, {'0002'});
    });
  });

  test('los mensajes de ubicación llevan acentos', () async {
    final vm = _fakeVm();
    addTearDown(vm.dispose);
    expect(vm.gpsStatusLabel, 'Sin ubicación capturada todavía');
    expect(vm.exerciseData.progressLabel, 'Sesión en curso');

    await vm.requestGpsLocation();
    expect(
      vm.gpsStatusLabel,
      'No se pudo obtener GPS. Usa zona manual o continúa sin ubicación.',
    );
  });
}

TrackerViewModel _fakeVm({
  FakeWorkoutsRepository? repository,
  int initialSetCount = 3,
}) => TrackerViewModel(
  repository: repository ?? FakeWorkoutsRepository(sessions: const []),
  exerciseId: '0001',
  exerciseName: 'Press',
  locationProvider: _FakeLocation(),
  autoStartSessionTimer: false,
  initialSetCount: initialSetCount,
  now: () => DateTime.utc(2026, 11, 12, 12),
);
