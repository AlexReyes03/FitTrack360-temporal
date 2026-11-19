import 'dart:async';

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
  FakeStepsSensor({this.snapshots = const []});

  final List<StepsSnapshot> snapshots;
  final _controller = StreamController<StepsSnapshot>.broadcast();
  bool disposed = false;

  void emit(StepsSnapshot snapshot) {
    if (!_controller.isClosed) _controller.add(snapshot);
  }

  @override
  Stream<StepsSnapshot> watchDailySteps() {
    scheduleMicrotask(() {
      for (final snapshot in snapshots) {
        if (!_controller.isClosed) _controller.add(snapshot);
      }
    });
    return _controller.stream;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
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
