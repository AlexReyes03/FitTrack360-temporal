import 'dart:async';

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/steps_sensor.dart';

/// Pasos del día con `pedometer` + `ACTIVITY_RECOGNITION` / motion (O5).
///
/// Si el permiso o el hardware fallan, emite [StepsSnapshot.unavailableDevice]
/// una sola vez y cierra el stream de forma controlada.
class PedometerStepsSensor implements StepsSensor {
  PedometerStepsSensor({
    this._stepCountStream,
    Future<PermissionStatus> Function()? requestActivityPermission,
    DateTime Function()? now,
  }) : _requestActivityPermission =
           requestActivityPermission ?? Permission.activityRecognition.request,
       _now = now ?? DateTime.now;

  final Stream<StepCount>? _stepCountStream;
  final Future<PermissionStatus> Function() _requestActivityPermission;
  final DateTime Function() _now;

  StreamSubscription<StepCount>? _subscription;
  final _controller = StreamController<StepsSnapshot>.broadcast();
  int? _baseline;
  String? _baselineDayKey;

  @override
  Stream<StepsSnapshot> watchDailySteps() {
    unawaited(_start());
    return _controller.stream;
  }

  Future<void> _start() async {
    try {
      final status = await _requestActivityPermission();
      if (!status.isGranted) {
        _emitUnavailable();
        return;
      }

      final stream = _stepCountStream ?? Pedometer.stepCountStream;
      _subscription = stream.listen(
        _onStepCount,
        onError: (_) => _emitUnavailable(),
        cancelOnError: true,
      );
    } catch (_) {
      _emitUnavailable();
    }
  }

  void _onStepCount(StepCount event) {
    final dayKey = _dayKey(_now());
    if (_baseline == null || _baselineDayKey != dayKey) {
      _baseline = event.steps;
      _baselineDayKey = dayKey;
    }
    final daily = (event.steps - _baseline!).clamp(0, 1 << 30);
    if (!_controller.isClosed) {
      _controller.add(StepsSnapshot(steps: daily));
    }
  }

  void _emitUnavailable() {
    if (!_controller.isClosed) {
      _controller.add(StepsSnapshot.unavailableDevice);
    }
  }

  String _dayKey(DateTime instant) {
    final local = instant.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
