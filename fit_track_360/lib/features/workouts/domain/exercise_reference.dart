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
  final latest = _latestSessionWith(
    sessions: sessions,
    exerciseId: exerciseId,
    currentSessionId: currentSessionId,
    currentStartedAt: currentStartedAt,
  );
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

/// Igual que [findPreviousSetReference], pero la serie equivalente es la que
/// ocupa [position] (desde 1) entre las series de [exerciseId] en esa sesión,
/// ordenadas por `order`. Sirve cuando `order` es global en la sesión y se
/// mezclan varios ejercicios.
PreviousSetReference? findPreviousSetReferenceByPosition({
  required List<ExerciseHistorySession> sessions,
  required String exerciseId,
  required String currentSessionId,
  required DateTime currentStartedAt,
  required int position,
}) {
  if (position < 1) return null;
  final latest = _latestSessionWith(
    sessions: sessions,
    exerciseId: exerciseId,
    currentSessionId: currentSessionId,
    currentStartedAt: currentStartedAt,
  );
  if (latest == null) return null;

  final indexed = [
    for (var i = 0; i < latest.sets.length; i++)
      if (latest.sets[i].exerciseId == exerciseId) (i, latest.sets[i]),
  ];
  // Orden por `order` y, si falta o empata, por posición original (estable).
  indexed.sort((a, b) {
    final byOrder = (a.$2.order ?? a.$1).compareTo(b.$2.order ?? b.$1);
    return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
  });
  if (position > indexed.length) return null;
  final set = indexed[position - 1].$2;
  return PreviousSetReference(
    performedAt: latest.startedAt,
    weightKg: set.weightKg,
    reps: set.reps,
  );
}

ExerciseHistorySession? _latestSessionWith({
  required List<ExerciseHistorySession> sessions,
  required String exerciseId,
  required String currentSessionId,
  required DateTime currentStartedAt,
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
  return latest;
}
