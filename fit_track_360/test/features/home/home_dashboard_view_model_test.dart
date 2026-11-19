import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/home/domain/steps_sensor.dart';
import 'package:fit_track_360/features/home/presentation/home_dashboard_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_dashboard.dart';

void main() {
  final fixedNow = DateTime(2026, 11, 19, 12, 0);

  test('mapea nutrición, sesión y métrica desde el API', () async {
    final repo = FakeDashboardRepository(
      todayResult: sampleDashboard(
        session: sampleSession(),
        metric: sampleMetric(),
      ),
    );
    final steps = FakeStepsSensor(
      snapshots: [const StepsSnapshot(steps: 4200)],
    );
    final vm = HomeDashboardViewModel(
      repository: repo,
      stepsSensor: steps,
      now: () => fixedNow,
    );

    expect(vm.nutrition, isA<AsyncLoading>());
    await vm.load();

    expect(repo.todayCalls, 1);
    expect(repo.lastDate, '2026-11-19');
    expect(vm.nutrition, isA<AsyncData>());
    expect(vm.nutrition.dataOrNull!.consumedKcal, 1480);
    expect(vm.nutrition.dataOrNull!.targetKcal, 2100);
    expect(vm.session, isA<AsyncData>());
    expect(vm.session.dataOrNull!.title, 'Tren superior');
    expect(vm.metric, isA<AsyncData>());
    expect(vm.metric.dataOrNull!.weightValue, '74.2');
    expect(vm.metric.dataOrNull!.deltaLabel, 'Último registro corporal');

    await Future<void>.delayed(Duration.zero);
    expect(vm.steps, isA<AsyncData>());
    expect(vm.steps.dataOrNull!.stepsCount, 4200);
    expect(vm.stepsUnavailable, isFalse);

    vm.dispose();
  });

  test('sin comidas, sesión ni métrica deja bloques en empty', () async {
    final vm = HomeDashboardViewModel(
      repository: FakeDashboardRepository(
        todayResult: sampleDashboard(mealsLogged: 0),
      ),
      stepsSensor: FakeStepsSensor(
        snapshots: [StepsSnapshot.unavailableDevice],
      ),
      now: () => fixedNow,
    );

    await vm.load();
    await Future<void>.delayed(Duration.zero);

    expect(vm.nutrition, isA<AsyncEmpty>());
    expect(vm.session, isA<AsyncEmpty>());
    expect(vm.metric, isA<AsyncEmpty>());
    expect(vm.stepsUnavailable, isTrue);

    vm.dispose();
  });

  test('error de API marca los tres bloques remotos sin tumbar pasos', () async {
    final steps = FakeStepsSensor(
      snapshots: [const StepsSnapshot(steps: 100)],
    );
    final vm = HomeDashboardViewModel(
      repository: FakeDashboardRepository(
        error: const AuthApiException('No se pudo conectar'),
      ),
      stepsSensor: steps,
      now: () => fixedNow,
    );

    await vm.load();
    await Future<void>.delayed(Duration.zero);

    expect(vm.nutrition, isA<AsyncError>());
    expect(vm.session, isA<AsyncError>());
    expect(vm.metric, isA<AsyncError>());
    expect(vm.steps.dataOrNull!.stepsCount, 100);
    expect(vm.sessionExpired, isFalse);

    vm.dispose();
  });

  test('sesión expirada marca sessionExpired', () async {
    final vm = HomeDashboardViewModel(
      repository: FakeDashboardRepository(
        error: const SessionExpiredException(),
      ),
      stepsSensor: FakeStepsSensor(),
      now: () => fixedNow,
    );

    await vm.load();

    expect(vm.sessionExpired, isTrue);
    expect(vm.nutrition, isA<AsyncError>());

    vm.dispose();
  });
}
