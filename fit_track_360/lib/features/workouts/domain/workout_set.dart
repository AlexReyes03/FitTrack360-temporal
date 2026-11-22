/// Una serie registrada en una sesión: ejercicio, peso en kg y repeticiones.
class WorkoutSet {
  final String exerciseName;

  /// Identificador del catálogo; null en respuestas antiguas.
  final String? exerciseId;

  /// Orden dentro de la sesión; null en respuestas antiguas.
  final int? order;

  /// Peso en kg, o `null` si la serie no lo registra (peso corporal).
  final double? weightKg;
  final int reps;

  const WorkoutSet({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    this.exerciseId,
    this.order,
  });

  /// Volumen de la serie: peso × repeticiones. Sin peso no suma volumen.
  double get volumeKg => (weightKg ?? 0) * reps;
}
