import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/steps_sensor.dart';
import 'steps_baseline_store.dart';

/// Pasos del día con `pedometer` (O5).
///
/// - Android: pide `ACTIVITY_RECOGNITION` con `permission_handler`.
/// - iOS: no usa `permission_handler`, porque sin los macros
///   `PERMISSION_SENSORS` del Podfile (que no se versiona) siempre responde
///   denegado. Escuchar el stream de CoreMotion muestra el diálogo de
///   `NSMotionUsageDescription`; un error del stream se trata como negado.
///
/// El podómetro cuenta desde el último reinicio del teléfono. Para obtener
/// los pasos del día se guarda la primera lectura de cada día local
/// ([StepsBaseline]); si el acumulado baja (reinicio), la base se reinicia a
/// la lectura actual.
class PedometerStepsSensor implements StepsSensor {
  PedometerStepsSensor({
    TargetPlatform? platform,
    StepsBaselineStore? store,
    Stream<int> Function()? cumulativeSteps,
    Future<PermissionStatus> Function()? requestActivityPermission,
    Future<PermissionStatus> Function()? activityPermissionStatus,
    Future<bool> Function()? openSettings,
    DateTime Function()? now,
  }) : _platform = platform ?? defaultTargetPlatform,
       _store = store ?? SecureStepsBaselineStore(),
       _cumulativeSteps =
           cumulativeSteps ??
           (() => Pedometer.stepCountStream.map((event) => event.steps)),
       _requestActivityPermission =
           requestActivityPermission ?? Permission.activityRecognition.request,
       _activityPermissionStatus =
           activityPermissionStatus ??
           (() => Permission.activityRecognition.status),
       _openSettings = openSettings ?? openAppSettings,
       _now = now ?? DateTime.now;

  final TargetPlatform _platform;
  final StepsBaselineStore _store;
  final Stream<int> Function() _cumulativeSteps;
  final Future<PermissionStatus> Function() _requestActivityPermission;
  final Future<PermissionStatus> Function() _activityPermissionStatus;
  final Future<bool> Function() _openSettings;
  final DateTime Function() _now;

  StreamController<StepsSnapshot>? _active;
  StreamSubscription<int>? _subscription;
  StepsBaseline? _baseline;
  bool _motionAuthorizedSaved = false;

  bool get _isIOS => _platform == TargetPlatform.iOS;

  @override
  Future<bool> canReadWithoutPrompt() async {
    try {
      if (_isIOS) return await _store.readMotionAuthorized();
      return (await _activityPermissionStatus()).isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<StepsSnapshot> watchDailySteps() {
    _stop(_active);
    late final StreamController<StepsSnapshot> controller;
    controller = StreamController<StepsSnapshot>(
      onListen: () => unawaited(_start(controller)),
      onCancel: () => _stop(controller),
    );
    _active = controller;
    return controller.stream;
  }

  Future<void> _start(StreamController<StepsSnapshot> controller) async {
    try {
      if (!_isIOS) {
        final status = await _requestActivityPermission();
        if (!status.isGranted) {
          _emit(
            controller,
            StepsSnapshot.unavailableFor(
              status.isPermanentlyDenied || status.isRestricted
                  ? StepsUnavailableReason.blocked
                  : StepsUnavailableReason.denied,
            ),
          );
          return;
        }
      }

      _baseline ??= await _readBaseline();
      if (!identical(_active, controller)) return;

      _subscription = _cumulativeSteps().listen(
        (steps) => _onSteps(controller, steps),
        onError: (Object _) => _onStreamError(controller),
        cancelOnError: true,
      );
    } catch (_) {
      _emit(controller, StepsSnapshot.unavailableDevice);
    }
  }

  void _onSteps(StreamController<StepsSnapshot> controller, int cumulative) {
    final now = _now();
    final today = _dayKey(now);
    var baseline = _baseline;
    if (baseline == null ||
        baseline.day != today ||
        cumulative < baseline.steps) {
      baseline = StepsBaseline(day: today, steps: cumulative, capturedAt: now);
      _baseline = baseline;
      unawaited(_ignoreErrors(() => _store.writeBaseline(baseline!)));
    }
    if (_isIOS && !_motionAuthorizedSaved) {
      _motionAuthorizedSaved = true;
      unawaited(_ignoreErrors(() => _store.writeMotionAuthorized(true)));
    }
    _emit(
      controller,
      StepsSnapshot(
        steps: cumulative - baseline.steps,
        countingSince: baseline.capturedAt,
      ),
    );
  }

  void _onStreamError(StreamController<StepsSnapshot> controller) {
    _subscription = null;
    if (_isIOS) {
      // CoreMotion negado: iOS no vuelve a preguntar, solo desde Ajustes.
      _motionAuthorizedSaved = false;
      unawaited(_ignoreErrors(() => _store.writeMotionAuthorized(false)));
      _emit(
        controller,
        const StepsSnapshot.unavailableFor(StepsUnavailableReason.blocked),
      );
      return;
    }
    _emit(controller, StepsSnapshot.unavailableDevice);
  }

  Future<StepsBaseline?> _readBaseline() async {
    try {
      return await _store.readBaseline();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ignoreErrors(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // La línea base es una mejora; sin almacenamiento se cuenta en memoria.
    }
  }

  void _emit(StreamController<StepsSnapshot> controller, StepsSnapshot value) {
    if (identical(_active, controller) && !controller.isClosed) {
      controller.add(value);
    }
  }

  void _stop(StreamController<StepsSnapshot>? controller) {
    if (controller == null || !identical(_active, controller)) return;
    _active = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (!controller.isClosed) unawaited(controller.close());
  }

  static String _dayKey(DateTime instant) {
    final local = instant.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<void> openSettings() async {
    await _openSettings();
  }

  @override
  Future<void> dispose() async {
    _stop(_active);
  }
}
