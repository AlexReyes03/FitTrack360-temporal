import 'dart:async';

import 'package:fit_track_360/features/home/data/steps_baseline_store.dart';
import 'package:fit_track_360/features/home/domain/dashboard_repository.dart';
import 'package:fit_track_360/features/home/domain/dashboard_today.dart';
import 'package:fit_track_360/features/home/domain/steps_sensor.dart';

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({this.todayResult, this.error});

  DashboardToday? todayResult;
  Object? error;
  int todayCalls = 0;
  String? lastDate;
  int? lastUtcOffsetMinutes;

  @override
  Future<DashboardToday> today({
    required String date,
    required int utcOffsetMinutes,
  }) async {
    todayCalls++;
    lastDate = date;
    lastUtcOffsetMinutes = utcOffsetMinutes;
    final err = error;
    if (err != null) {
      if (err is Exception) throw err;
      throw Exception(err.toString());
    }
    final result = todayResult;
    if (result == null) {
      throw StateError('FakeDashboardRepository sin todayResult');
    }
    return result;
  }
}

class FakeStepsSensor implements StepsSensor {
  FakeStepsSensor({this.snapshots = const [], this.readyWithoutPrompt = true});

  /// Lecturas que se emiten en cada llamada a [watchDailySteps].
  List<StepsSnapshot> snapshots;

  /// Simula un permiso ya concedido (Android) o Motion ya autorizado (iOS).
  bool readyWithoutPrompt;

  int watchCalls = 0;
  int settingsOpened = 0;
  bool disposed = false;
  StreamController<StepsSnapshot>? _current;

  void emit(StepsSnapshot snapshot) {
    final current = _current;
    if (current != null && !current.isClosed) current.add(snapshot);
  }

  @override
  Future<bool> canReadWithoutPrompt() async => readyWithoutPrompt;

  @override
  Stream<StepsSnapshot> watchDailySteps() {
    watchCalls++;
    final batch = List<StepsSnapshot>.of(snapshots);
    late final StreamController<StepsSnapshot> controller;
    controller = StreamController<StepsSnapshot>(
      onListen: () => scheduleMicrotask(() {
        for (final snapshot in batch) {
          if (!controller.isClosed) controller.add(snapshot);
        }
      }),
    );
    _current = controller;
    return controller.stream;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _current?.close();
  }
}

/// Almacén en memoria para la línea base de pasos.
class InMemoryStepsBaselineStore implements StepsBaselineStore {
  InMemoryStepsBaselineStore({this.baseline, this.motionAuthorized = false});

  StepsBaseline? baseline;
  bool motionAuthorized;

  @override
  Future<StepsBaseline?> readBaseline() async => baseline;

  @override
  Future<void> writeBaseline(StepsBaseline value) async => baseline = value;

  @override
  Future<bool> readMotionAuthorized() async => motionAuthorized;

  @override
  Future<void> writeMotionAuthorized(bool value) async =>
      motionAuthorized = value;
}

DashboardToday sampleDashboard({
  int mealsLogged = 1,
  DaySession? session,
  LatestBodyMetric? metric,
}) {
  return DashboardToday(
    date: '2026-11-19',
    utcOffsetMinutes: -360,
    nutrition: DayNutrition(
      mealsLogged: mealsLogged,
      consumed: const Nutrients(
        calories: 1480.4,
        proteinG: 112.2,
        carbsG: 148.0,
        fatG: 46.1,
      ),
      goals: const NutritionGoalsSnapshot(
        dailyCalorieGoal: 2100,
        proteinGoalG: 150,
        carbsGoalG: 220,
        fatGoalG: 65,
      ),
      remaining: const Nutrients(
        calories: 619.6,
        proteinG: 37.8,
        carbsG: 72.0,
        fatG: 18.9,
      ),
    ),
    session: session,
    latestMetric: metric,
  );
}

DaySession sampleSession({bool isToday = true}) {
  return DaySession(
    id: 's1',
    startedAt: DateTime.parse('2026-11-19T13:30:00.000Z'),
    endedAt: DateTime.parse('2026-11-19T14:15:00.000Z'),
    notes: 'Tren superior',
    isToday: isToday,
  );
}

LatestBodyMetric sampleMetric() {
  return LatestBodyMetric(
    id: 'm1',
    measuredAt: DateTime.parse('2026-11-17T23:00:00.000Z'),
    weightKg: 74.2,
    bodyFatPercent: null,
    waistCm: null,
  );
}
