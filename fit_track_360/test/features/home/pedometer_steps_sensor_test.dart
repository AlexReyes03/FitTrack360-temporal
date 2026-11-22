import 'dart:async';

import 'package:fit_track_360/features/home/data/pedometer_steps_sensor.dart';
import 'package:fit_track_360/features/home/data/steps_baseline_store.dart';
import 'package:fit_track_360/features/home/domain/steps_sensor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fake_dashboard.dart';

/// Arma un sensor con dependencias falsas y expone lo que hizo.
class _Harness {
  _Harness({
    this.platform = TargetPlatform.android,
    this.permission = PermissionStatus.granted,
    StepsBaseline? storedBaseline,
    bool motionAuthorized = false,
    required this.now,
  }) : store = InMemoryStepsBaselineStore(
         baseline: storedBaseline,
         motionAuthorized: motionAuthorized,
       );

  final TargetPlatform platform;
  PermissionStatus permission;
  final InMemoryStepsBaselineStore store;
  DateTime now;
  final steps = StreamController<int>.broadcast();
  int permissionRequests = 0;
  int streamListens = 0;
  int settingsOpened = 0;

  late final PedometerStepsSensor sensor = PedometerStepsSensor(
    platform: platform,
    store: store,
    now: () => now,
    cumulativeSteps: () {
      streamListens++;
      return steps.stream;
    },
    requestActivityPermission: () async {
      permissionRequests++;
      return permission;
    },
    activityPermissionStatus: () async => permission,
    openSettings: () async {
      settingsOpened++;
      return true;
    },
  );

  Future<List<StepsSnapshot>> listen() async {
    final events = <StepsSnapshot>[];
    sensor.watchDailySteps().listen(events.add);
    await pumpEventQueue();
    return events;
  }
}

void main() {
  final morning = DateTime(2026, 11, 21, 8, 0);

  group('PedometerStepsSensor línea base diaria', () {
    test('la primera lectura del día fija la línea base y la guarda', () async {
      final h = _Harness(now: morning);
      final events = await h.listen();

      h.steps.add(5000);
      await pumpEventQueue();
      h.now = morning.add(const Duration(hours: 1));
      h.steps.add(5600);
      await pumpEventQueue();

      expect(events.map((e) => e.steps), [0, 600]);
      expect(events.last.countingSince, morning);
      expect(h.store.baseline!.day, '2026-11-21');
      expect(h.store.baseline!.steps, 5000);
    });

    test('usa la línea base guardada del mismo día al reabrir', () async {
      final h = _Harness(
        now: morning.add(const Duration(hours: 4)),
        storedBaseline: StepsBaseline(
          day: '2026-11-21',
          steps: 5000,
          capturedAt: morning,
        ),
      );
      final events = await h.listen();

      h.steps.add(7300);
      await pumpEventQueue();

      expect(events.single.steps, 2300);
      expect(events.single.countingSince, morning);
      expect(h.store.baseline!.steps, 5000);
    });

    test(
      'al reiniciar el teléfono (acumulado menor) reinicia la base',
      () async {
        final h = _Harness(
          now: morning.add(const Duration(hours: 6)),
          storedBaseline: StepsBaseline(
            day: '2026-11-21',
            steps: 5000,
            capturedAt: morning,
          ),
        );
        final events = await h.listen();

        h.steps.add(300);
        await pumpEventQueue();
        h.steps.add(450);
        await pumpEventQueue();

        expect(events.map((e) => e.steps), [0, 150]);
        expect(h.store.baseline!.steps, 300);
        expect(
          h.store.baseline!.capturedAt,
          morning.add(const Duration(hours: 6)),
        );
      },
    );

    test('al cambiar de día descarta la base anterior', () async {
      final h = _Harness(
        now: morning,
        storedBaseline: StepsBaseline(
          day: '2026-11-20',
          steps: 1000,
          capturedAt: DateTime(2026, 11, 20, 7),
        ),
      );
      final events = await h.listen();

      h.steps.add(9000);
      await pumpEventQueue();
      expect(events.last.steps, 0);
      expect(h.store.baseline!.day, '2026-11-21');

      h.steps.add(9400);
      await pumpEventQueue();
      expect(events.last.steps, 400);

      // Medianoche con la app abierta.
      h.now = DateTime(2026, 11, 22, 0, 5);
      h.steps.add(9500);
      await pumpEventQueue();
      expect(events.last.steps, 0);
      expect(h.store.baseline!.day, '2026-11-22');
      expect(h.store.baseline!.steps, 9500);
    });
  });

  group('PedometerStepsSensor en Android', () {
    test('permiso denegado emite no disponible y no lee el sensor', () async {
      final h = _Harness(now: morning, permission: PermissionStatus.denied);
      final events = await h.listen();

      expect(h.permissionRequests, 1);
      expect(h.streamListens, 0);
      expect(events.single.unavailable, isTrue);
      expect(events.single.reason, StepsUnavailableReason.denied);
    });

    test('denegado de forma permanente pide ir a Ajustes', () async {
      final h = _Harness(
        now: morning,
        permission: PermissionStatus.permanentlyDenied,
      );
      final events = await h.listen();

      expect(events.single.reason, StepsUnavailableReason.blocked);
    });

    test(
      'canReadWithoutPrompt consulta el estado sin pedir el permiso',
      () async {
        final h = _Harness(now: morning, permission: PermissionStatus.denied);
        expect(await h.sensor.canReadWithoutPrompt(), isFalse);

        h.permission = PermissionStatus.granted;
        expect(await h.sensor.canReadWithoutPrompt(), isTrue);
        expect(h.permissionRequests, 0);
      },
    );

    test('reintentar vuelve a pedir el permiso y empieza a leer', () async {
      final h = _Harness(now: morning, permission: PermissionStatus.denied);
      await h.listen();

      h.permission = PermissionStatus.granted;
      final events = await h.listen();
      h.steps.add(1200);
      await pumpEventQueue();

      expect(h.permissionRequests, 2);
      expect(h.streamListens, 1);
      expect(events.single.steps, 0);
    });
  });

  group('PedometerStepsSensor en iOS', () {
    test('no usa permission_handler: el stream dispara CoreMotion', () async {
      final h = _Harness(
        platform: TargetPlatform.iOS,
        now: morning,
        // permission_handler en iOS responde siempre permanentlyDenied sin
        // los macros del Podfile; no debe consultarse.
        permission: PermissionStatus.permanentlyDenied,
      );
      final events = await h.listen();
      h.steps.add(800);
      await pumpEventQueue();

      expect(h.permissionRequests, 0);
      expect(h.streamListens, 1);
      expect(events.single.steps, 0);
      expect(events.single.unavailable, isFalse);
      expect(h.store.motionAuthorized, isTrue);
      expect(await h.sensor.canReadWithoutPrompt(), isTrue);
    });

    test('un error del stream (motion negado) emite no disponible', () async {
      final h = _Harness(
        platform: TargetPlatform.iOS,
        now: morning,
        motionAuthorized: true,
      );
      final events = await h.listen();
      h.steps.addError(Exception('CMErrorMotionActivityNotAuthorized'));
      await pumpEventQueue();

      expect(events.single.unavailable, isTrue);
      expect(events.single.reason, StepsUnavailableReason.blocked);
      expect(h.store.motionAuthorized, isFalse);
      expect(await h.sensor.canReadWithoutPrompt(), isFalse);
    });

    test('sin autorización previa no se puede leer sin preguntar', () async {
      final h = _Harness(platform: TargetPlatform.iOS, now: morning);
      expect(await h.sensor.canReadWithoutPrompt(), isFalse);
    });
  });

  test('openSettings delega en el sistema', () async {
    final h = _Harness(now: morning);
    await h.sensor.openSettings();
    expect(h.settingsOpened, 1);
  });

  test('dispose deja de escuchar el sensor', () async {
    final h = _Harness(now: morning);
    await h.listen();
    expect(h.steps.hasListener, isTrue);

    await h.sensor.dispose();
    expect(h.steps.hasListener, isFalse);
  });
}
