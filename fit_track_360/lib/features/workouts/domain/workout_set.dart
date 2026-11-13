/// Una serie registrada en una sesión: ejercicio, peso en kg y repeticiones.
class WorkoutSet {
  final String exerciseName;
  final double weightKg;
  final int reps;

  const WorkoutSet({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
  });

  /// Volumen de la serie: peso × repeticiones.
  double get volumeKg => weightKg * reps;
}
