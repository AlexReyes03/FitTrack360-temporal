import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_detail_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_workouts_repository.dart';

void main() {
  final previous = fakeSession(
    id: 'anterior',
    startedAt: detailStart.subtract(const Duration(days: 2)),
    duration: const Duration(minutes: 45),
    sets: const [WorkoutSet(exerciseName: 'Sentadilla', weightKg: 90, reps: 5)],
  );

  test('carga el resumen y la comparación con la sesión anterior', () async {
    final viewModel = WorkoutDetailViewModel(
      repository: FakeWorkoutsRepository(sessions: [fakeSession(), previous]),
      sessionId: 'actual',
    );

    expect(viewModel.summary, isA<AsyncLoading>());
    await viewModel.load();

    final summary = viewModel.summary.dataOrNull!;
    expect(summary.volumeKg, 1600);
    expect(summary.setCount, 3);
    final comparison = viewModel.comparison.dataOrNull!;
    expect(comparison.volumeDeltaKg, 1150);
    expect(comparison.setCountDelta, 2);
    expect(comparison.durationDelta, const Duration(minutes: 15));
  });

  test(
    'sin sesión previa la comparación queda vacía y el resumen se muestra',
    () async {
      final viewModel = WorkoutDetailViewModel(
        repository: FakeWorkoutsRepository(sessions: [fakeSession()]),
        sessionId: 'actual',
      );

      await viewModel.load();

      expect(viewModel.summary, isA<AsyncData>());
      expect(viewModel.comparison, isA<AsyncEmpty>());
    },
  );

  test(
    'si falla la lista la comparación da error sin bloquear el resumen',
    () async {
      final viewModel = WorkoutDetailViewModel(
        repository: FakeWorkoutsRepository(
          sessions: [fakeSession()],
          listError: const AuthApiException('No se pudo conectar'),
        ),
        sessionId: 'actual',
      );

      await viewModel.load();

      expect(viewModel.summary, isA<AsyncData>());
      expect(viewModel.comparison, isA<AsyncError>());
    },
  );

  test('si falla la sesión el estado es error', () async {
    final viewModel = WorkoutDetailViewModel(
      repository: FakeWorkoutsRepository(
        sessions: const [],
        getError: const AuthApiException('No se pudo conectar'),
      ),
      sessionId: 'actual',
    );

    await viewModel.load();

    expect(viewModel.summary, isA<AsyncError>());
  });
}
