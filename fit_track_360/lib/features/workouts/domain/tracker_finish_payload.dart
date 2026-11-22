/// Serie lista para `POST /workouts` desde el tracker live.
class TrackerFinishSet {
  const TrackerFinishSet({
    required this.exerciseId,
    required this.order,
    required this.weightKg,
    required this.reps,
  });

  final String exerciseId;
  final int order;

  /// `0` representa peso corporal / sin carga (contrato API).
  final double weightKg;
  final int reps;
}

/// Cuerpo de finalizacion de una sesion activa del tracker.
class TrackerFinishPayload {
  const TrackerFinishPayload({
    required this.startedAt,
    required this.endedAt,
    required this.sets,
    this.notes,
    this.location,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final String? notes;
  final String? location;
  final List<TrackerFinishSet> sets;

  Map<String, dynamic> toCreateWorkoutPayload() {
    final trimmedNotes = notes?.trim();
    final trimmedLocation = location?.trim();
    return {
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
      if (trimmedNotes != null && trimmedNotes.isNotEmpty)
        'notes': trimmedNotes,
      if (trimmedLocation != null && trimmedLocation.isNotEmpty)
        'location': trimmedLocation,
      if (sets.isNotEmpty)
        'sets': [
          for (final set in sets)
            {
              'exerciseId': set.exerciseId,
              'order': set.order,
              'weight': set.weightKg,
              'reps': set.reps,
            },
        ],
    };
  }
}
