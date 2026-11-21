/// Lectura local de pasos del día (O5). Sin API.
class StepsSnapshot {
  const StepsSnapshot({required this.steps, this.unavailable = false});

  final int steps;
  final bool unavailable;

  static const StepsSnapshot unavailableDevice = StepsSnapshot(
    steps: 0,
    unavailable: true,
  );
}

/// Fuente de pasos del dispositivo. Fallos de permiso/hardware degradan
/// el bloque sin tumbar el resto del dashboard.
abstract class StepsSensor {
  /// Emite lecturas; la primera puede ser loading vía ausencia de eventos.
  Stream<StepsSnapshot> watchDailySteps();

  Future<void> dispose();
}
