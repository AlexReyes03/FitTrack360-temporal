/// Motivo por el que el bloque de pasos no puede mostrar datos.
enum StepsUnavailableReason {
  /// El usuario negó el permiso, pero el sistema puede volver a preguntar.
  denied,

  /// El sistema ya no vuelve a preguntar (Android: denegado de forma
  /// permanente; iOS: Motion negado). Solo se activa desde Ajustes.
  blocked,

  /// Sin sensor o fallo del hardware.
  sensorError,
}

/// Lectura local de pasos del día (O5). Sin API.
class StepsSnapshot {
  const StepsSnapshot({
    required this.steps,
    this.unavailable = false,
    this.reason,
    this.countingSince,
  });

  const StepsSnapshot.unavailableFor(StepsUnavailableReason this.reason)
    : steps = 0,
      unavailable = true,
      countingSince = null;

  final int steps;
  final bool unavailable;
  final StepsUnavailableReason? reason;

  /// Momento de la primera lectura del día. El podómetro cuenta desde el
  /// último reinicio del teléfono, así que los pasos previos a esta hora no
  /// se pueden recuperar.
  final DateTime? countingSince;

  static const StepsSnapshot unavailableDevice = StepsSnapshot.unavailableFor(
    StepsUnavailableReason.sensorError,
  );
}

/// Fuente de pasos del dispositivo. Fallos de permiso/hardware degradan
/// el bloque sin tumbar el resto del dashboard.
abstract class StepsSensor {
  /// `true` si ya se puede leer sin mostrar un diálogo del sistema.
  Future<bool> canReadWithoutPrompt();

  /// Pide el permiso cuando aplica y emite lecturas. Solo se llama tras la
  /// acción «Mostrar mis pasos» o si [canReadWithoutPrompt] es `true`. Cada
  /// llamada reinicia la lectura (sirve para «Reintentar»).
  Stream<StepsSnapshot> watchDailySteps();

  /// Abre los ajustes de la app en el sistema.
  Future<void> openSettings();

  Future<void> dispose();
}
