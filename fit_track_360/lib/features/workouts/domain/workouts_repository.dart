import '../data/workout_session.dart';

/// Contrato de acceso a las sesiones de entrenamiento del usuario.
abstract interface class WorkoutsRepository {
  Future<WorkoutSession> getById(String id);

  Future<List<WorkoutSession>> list();
}
