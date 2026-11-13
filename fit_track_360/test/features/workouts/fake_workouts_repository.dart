import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/domain/workouts_repository.dart';

final detailStart = DateTime.utc(2026, 11, 4, 10);

WorkoutSession fakeSession({
  String id = 'actual',
  DateTime? startedAt,
  Duration? duration = const Duration(minutes: 60),
  String? notes = 'Buen progreso en sentadilla',
  List<WorkoutSet> sets = const [
    WorkoutSet(exerciseName: 'Sentadilla', weightKg: 100, reps: 5),
    WorkoutSet(exerciseName: 'Sentadilla', weightKg: 100, reps: 5),
    WorkoutSet(exerciseName: 'Press banca', weightKg: 60, reps: 10),
  ],
}) {
  final start = startedAt ?? detailStart;
  return WorkoutSession(
    id: id,
    userId: 'u1',
    startedAt: start,
    endedAt: duration == null ? null : start.add(duration),
    notes: notes,
    createdAt: start,
    updatedAt: start,
    sets: sets,
  );
}

/// Doble del repositorio: devuelve las sesiones dadas o lanza los errores.
class FakeWorkoutsRepository implements WorkoutsRepository {
  FakeWorkoutsRepository({
    required this.sessions,
    this.getError,
    this.listError,
  });

  final List<WorkoutSession> sessions;
  final Object? getError;
  final Object? listError;

  @override
  Future<WorkoutSession> getById(String id) async {
    if (getError != null) throw getError!;
    return sessions.firstWhere((session) => session.id == id);
  }

  @override
  Future<List<WorkoutSession>> list() async {
    if (listError != null) throw listError!;
    return sessions;
  }
}

class FakeSessionStorage implements SessionStorage {
  @override
  Future<String?> readAccessToken() async => 'access';

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}
