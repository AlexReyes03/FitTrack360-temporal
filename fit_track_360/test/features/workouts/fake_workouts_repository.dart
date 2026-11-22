import 'dart:async';
import 'dart:ui' show Rect;

import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/domain/workout_summary_sharer.dart';
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

/// Sesión con identificadores y orden listos para repetir.
WorkoutSession repeatableSession({String id = 'actual', DateTime? startedAt}) =>
    fakeSession(
      id: id,
      startedAt: startedAt,
      sets: const [
        WorkoutSet(
          exerciseId: 'ej-a',
          exerciseName: 'Sentadilla',
          order: 1,
          weightKg: 100,
          reps: 5,
        ),
        WorkoutSet(
          exerciseId: 'ej-a',
          exerciseName: 'Sentadilla',
          order: 2,
          weightKg: 110,
          reps: 3,
        ),
        WorkoutSet(
          exerciseId: 'ej-b',
          exerciseName: 'Press banca',
          order: 3,
          weightKg: 60,
          reps: 10,
        ),
      ],
    );

/// Doble del repositorio: devuelve las sesiones dadas o lanza los errores.
class FakeWorkoutsRepository implements WorkoutsRepository {
  FakeWorkoutsRepository({
    required this.sessions,
    this.getError,
    this.listError,
    this.createError,
  });

  final List<WorkoutSession> sessions;
  Object? getError;
  final Object? listError;
  final Object? createError;
  int getCalls = 0;

  /// Cuerpos recibidos por [createWithPayload], en orden.
  final List<Map<String, dynamic>> createdPayloads = [];

  @override
  Future<WorkoutSession> getById(String id) async {
    getCalls++;
    if (getError != null) throw getError!;
    return sessions.firstWhere((session) => session.id == id);
  }

  @override
  Future<List<WorkoutSession>> list() async {
    if (listError != null) throw listError!;
    return sessions;
  }

  @override
  Future<WorkoutSession> createWithPayload(Map<String, dynamic> payload) async {
    createdPayloads.add(payload);
    if (createError != null) throw createError!;
    return fakeSession(id: 'created-${createdPayloads.length}');
  }
}

class FakeWorkoutSummarySharer implements WorkoutSummarySharer {
  FakeWorkoutSummarySharer({
    this.result = WorkoutShareResult.shared,
    this.error,
  });

  final WorkoutShareResult result;
  final Object? error;
  final calls = <({String text, Rect? origin})>[];

  @override
  Future<WorkoutShareResult> shareText({
    required String text,
    Rect? origin,
  }) async {
    calls.add((text: text, origin: origin));
    if (error != null) throw error!;
    return result;
  }
}

/// Comparte solo cuando la prueba completa el gate, para observar el estado
/// intermedio y las pulsaciones repetidas.
class GatedWorkoutSummarySharer implements WorkoutSummarySharer {
  final gate = Completer<WorkoutShareResult>();
  int calls = 0;

  @override
  Future<WorkoutShareResult> shareText({required String text, Rect? origin}) {
    calls++;
    return gate.future;
  }
}

/// Repositorio cuya carga no termina hasta que la prueba lo decide.
class GatedWorkoutsRepository extends FakeWorkoutsRepository {
  GatedWorkoutsRepository({super.sessions = const []});

  final gate = Completer<void>();
  int calls = 0;

  @override
  Future<WorkoutSession> getById(String id) async {
    calls++;
    await gate.future;
    return super.getById(id);
  }
}

class FakeSessionStorage implements SessionStorage {
  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      'access';

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
