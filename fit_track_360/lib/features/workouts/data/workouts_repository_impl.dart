import '../domain/workouts_repository.dart';
import 'workout_session.dart';
import 'workouts_api.dart';

/// Implementación de [WorkoutsRepository] sobre el API REST.
class ApiWorkoutsRepository implements WorkoutsRepository {
  final WorkoutsApi _api;

  ApiWorkoutsRepository(this._api);

  @override
  Future<WorkoutSession> getById(String id) => _api.getById(id);

  @override
  Future<List<WorkoutSession>> list() => _api.list();
}
