import 'dart:async';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/home/domain/dashboard_repository.dart';
import 'package:fit_track_360/features/home/domain/dashboard_today.dart';
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
    expect(repo.lastUtcOffsetMinutes, fixedNow.timeZoneOffset.inMinutes);
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

  test(
    'error de API marca los tres bloques remotos sin tumbar pasos',
    () async {
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
    },
  );

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

  group('pasos en contexto (O5)', () {
    test('sin permiso previo no abre el sensor y pide la acción', () async {
      final sensor = FakeStepsSensor(
        readyWithoutPrompt: false,
        snapshots: [const StepsSnapshot(steps: 900)],
      );
      final vm = HomeDashboardViewModel(
        repository: FakeDashboardRepository(todayResult: sampleDashboard()),
        stepsSensor: sensor,
        now: () => fixedNow,
      );

      await vm.load();
      await pumpEventQueue();

      expect(sensor.watchCalls, 0);
      expect(vm.stepsNeedPermission, isTrue);
      expect(vm.stepsUnavailable, isFalse);

      vm.enableSteps();
      await pumpEventQueue();

      expect(sensor.watchCalls, 1);
      expect(vm.stepsNeedPermission, isFalse);
      expect(vm.steps.dataOrNull!.stepsCount, 900);

      vm.dispose();
    });

    test('tocar la acción durante la consulta inicial no se pierde', () async {
      final sensor = FakeStepsSensor(
        readyWithoutPrompt: false,
        snapshots: [const StepsSnapshot(steps: 55)],
      );
      final vm = HomeDashboardViewModel(
        repository: FakeDashboardRepository(todayResult: sampleDashboard()),
        stepsSensor: sensor,
        now: () => fixedNow,
      );

      final loading = vm.load();
      vm.enableSteps();
      await loading;
      await pumpEventQueue();

      expect(vm.stepsNeedPermission, isFalse);
      expect(vm.steps.dataOrNull!.stepsCount, 55);
      vm.dispose();
    });

    test('recargar el dashboard no vuelve a abrir el sensor', () async {
      final sensor = FakeStepsSensor(
        snapshots: [const StepsSnapshot(steps: 10)],
      );
      final vm = HomeDashboardViewModel(
        repository: FakeDashboardRepository(todayResult: sampleDashboard()),
        stepsSensor: sensor,
        now: () => fixedNow,
      );

      await vm.load();
      await vm.load();
      await pumpEventQueue();

      expect(sensor.watchCalls, 1);
      vm.dispose();
    });

    test('Reintentar tras no disponible vuelve a escuchar el sensor', () async {
      final sensor = FakeStepsSensor(
        snapshots: [
          const StepsSnapshot.unavailableFor(StepsUnavailableReason.denied),
        ],
      );
      final vm = HomeDashboardViewModel(
        repository: FakeDashboardRepository(todayResult: sampleDashboard()),
        stepsSensor: sensor,
        now: () => fixedNow,
      );

      await vm.load();
      await pumpEventQueue();
      expect(vm.stepsUnavailable, isTrue);
      expect(vm.stepsUnavailableReason, StepsUnavailableReason.denied);
      expect(vm.stepsCanOpenSettings, isFalse);

      sensor.snapshots = [const StepsSnapshot(steps: 321)];
      vm.retrySteps();
      await pumpEventQueue();

      expect(sensor.watchCalls, 2);
      expect(vm.stepsUnavailable, isFalse);
      expect(vm.steps.dataOrNull!.stepsCount, 321);
      vm.dispose();
    });

    test('bloqueado ofrece abrir Ajustes', () async {
      final sensor = FakeStepsSensor(
        snapshots: [
          const StepsSnapshot.unavailableFor(StepsUnavailableReason.blocked),
        ],
      );
      final vm = HomeDashboardViewModel(
        repository: FakeDashboardRepository(todayResult: sampleDashboard()),
        stepsSensor: sensor,
        now: () => fixedNow,
      );

      await vm.load();
      await pumpEventQueue();
      expect(vm.stepsCanOpenSettings, isTrue);

      await vm.openStepsSettings();
      expect(sensor.settingsOpened, 1);
      vm.dispose();
    });

    test('indica desde qué hora se cuentan los pasos', () async {
      final vm = HomeDashboardViewModel(
        repository: FakeDashboardRepository(todayResult: sampleDashboard()),
        stepsSensor: FakeStepsSensor(
          snapshots: [
            StepsSnapshot(
              steps: 1500,
              countingSince: DateTime(2026, 11, 19, 8, 5),
            ),
          ],
        ),
        now: () => fixedNow,
      );

      await vm.load();
      await pumpEventQueue();

      expect(vm.steps.dataOrNull!.subtitle, 'Contados desde las 08:05 de hoy');
      vm.dispose();
    });
  });

  test('una carga vieja no pisa la respuesta de una carga nueva', () async {
    final repo = _ScriptedRepository();
    final vm = HomeDashboardViewModel(
      repository: repo,
      stepsSensor: FakeStepsSensor(),
      now: () => fixedNow,
    );

    final first = vm.load();
    final second = vm.load();
    repo.pending[1].complete(sampleDashboard(session: sampleSession()));
    await second;
    repo.pending[0].complete(sampleDashboard(mealsLogged: 0));
    await first;

    expect(vm.session, isA<AsyncData>());
    expect(vm.nutrition, isA<AsyncData>());
    vm.dispose();
  });

  test('un error viejo no pisa la respuesta de una carga nueva', () async {
    final repo = _ScriptedRepository();
    final vm = HomeDashboardViewModel(
      repository: repo,
      stepsSensor: FakeStepsSensor(),
      now: () => fixedNow,
    );

    final first = vm.load();
    final second = vm.load();
    repo.pending[1].complete(sampleDashboard());
    await second;
    repo.pending[0].completeError(const SessionExpiredException());
    await first;

    expect(vm.sessionExpired, isFalse);
    expect(vm.nutrition, isA<AsyncData>());
    vm.dispose();
  });

  test('refresh conserva los bloques visibles mientras recarga', () async {
    final repo = FakeDashboardRepository(
      todayResult: sampleDashboard(
        session: sampleSession(),
        metric: sampleMetric(),
      ),
    );
    final vm = HomeDashboardViewModel(
      repository: repo,
      stepsSensor: FakeStepsSensor(
        snapshots: [StepsSnapshot.unavailableDevice],
      ),
      now: () => fixedNow,
    );
    await vm.load();

    repo.todayResult = sampleDashboard(mealsLogged: 0);
    final pending = vm.refresh();

    // Sin esqueletos: el usuario sigue viendo lo anterior mientras recarga.
    expect(vm.nutrition, isA<AsyncData>());
    expect(vm.session, isA<AsyncData>());
    expect(vm.metric, isA<AsyncData>());

    await pending;
    expect(repo.todayCalls, 2);
    expect(vm.nutrition, isA<AsyncEmpty>());
    expect(vm.session, isA<AsyncEmpty>());
    expect(vm.metric, isA<AsyncEmpty>());

    vm.dispose();
  });

  test('refresh tras un error vuelve a mostrar la carga', () async {
    final repo = FakeDashboardRepository(error: Exception('500'));
    final vm = HomeDashboardViewModel(
      repository: repo,
      stepsSensor: FakeStepsSensor(
        snapshots: [StepsSnapshot.unavailableDevice],
      ),
      now: () => fixedNow,
    );
    await vm.load();
    expect(vm.nutrition, isA<AsyncError>());

    repo
      ..error = null
      ..todayResult = sampleDashboard();
    final pending = vm.refresh();
    expect(vm.nutrition, isA<AsyncLoading>());

    await pending;
    expect(vm.nutrition, isA<AsyncData>());

    vm.dispose();
  });
}

class _ScriptedRepository implements DashboardRepository {
  final pending = <Completer<DashboardToday>>[];

  @override
  Future<DashboardToday> today({
    required String date,
    required int utcOffsetMinutes,
  }) {
    final completer = Completer<DashboardToday>();
    pending.add(completer);
    return completer.future;
  }
}
