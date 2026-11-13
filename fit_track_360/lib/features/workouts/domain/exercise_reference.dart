/// Serie registrada en una sesión, tal como se usa para comparar.
class ExerciseSetRecord {
  final String exerciseId;

  /// Posición que reporta el API. Se conserva sin interpretar: todavía no se
  /// confirma que sea un ordinal por ejercicio, así que el llamador decide
  /// qué serie considera equivalente.
  final int? order;

  /// Peso en kg, o `null` si la serie no lo registra. Un `0` no se trata como
  /// peso corporal mientras el contrato no lo confirme.
  final double? weightKg;

  final int reps;

  const ExerciseSetRecord({
    required this.exerciseId,
    this.order,
    this.weightKg,
    required this.reps,
  });
}

/// Sesión histórica con las series disponibles para la referencia.
class ExerciseHistorySession {
  final String sessionId;
  final DateTime startedAt;

  /// `null` mientras la sesión no ha terminado.
  final DateTime? endedAt;
  final List<ExerciseSetRecord> sets;

  const ExerciseHistorySession({
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.sets,
  });
}

/// Serie previa que sirve de referencia para la serie en captura.
class PreviousSetReference {
  final DateTime performedAt;
  final double? weightKg;
  final int reps;

  const PreviousSetReference({
    required this.performedAt,
    required this.weightKg,
    required this.reps,
  });
}

/// Busca la serie equivalente en la sesión terminada más reciente que contenga
/// [exerciseId] y haya empezado antes de [currentStartedAt].
///
/// [equivalent] define qué serie cuenta como equivalente; por ejemplo,
/// `(set) => set.order == orden`. La posición no se interpreta aquí porque su
/// significado depende de que backend confirme el contrato de `order`.
///
/// Devuelve `null` si no hay historial o si esa sesión no tiene la serie
/// equivalente. No consulta sesiones más antiguas en ese caso.
PreviousSetReference? findPreviousSetReference({
  required List<ExerciseHistorySession> sessions,
  required String exerciseId,
  required String currentSessionId,
  required DateTime currentStartedAt,
  required bool Function(ExerciseSetRecord set) equivalent,
}) {
  ExerciseHistorySession? latest;
  for (final session in sessions) {
    if (session.sessionId == currentSessionId) continue;
    if (session.endedAt == null) continue;
    if (!session.startedAt.isBefore(currentStartedAt)) continue;
    if (!session.sets.any((set) => set.exerciseId == exerciseId)) continue;
    if (latest == null || session.startedAt.isAfter(latest.startedAt)) {
      latest = session;
    }
  }
  if (latest == null) return null;

  for (final set in latest.sets) {
    if (set.exerciseId != exerciseId) continue;
    if (!equivalent(set)) continue;
    return PreviousSetReference(
      performedAt: latest.startedAt,
      weightKg: set.weightKg,
      reps: set.reps,
    );
  }
  return null;
}
