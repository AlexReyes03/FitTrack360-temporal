import 'dart:ui' show Rect;

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_not_found_exception.dart';
import 'package:fit_track_360/features/workouts/domain/workout_set.dart';
import 'package:fit_track_360/features/workouts/domain/workout_summary_sharer.dart';
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

  group('compartir el resumen', () {
    test(
      'envía fecha, duración, volumen, series y ejercicios sin notas',
      () async {
        final sharer = FakeWorkoutSummarySharer();
        final viewModel = WorkoutDetailViewModel(
          repository: FakeWorkoutsRepository(sessions: [fakeSession()]),
          sessionId: 'actual',
          sharer: sharer,
        );

        await viewModel.load();
        await viewModel.shareSummary();

        final text = sharer.calls.single.text;
        expect(text, contains('Fecha:'));
        expect(text, contains('Duración: 1 h 0 min'));
        expect(text, contains('Volumen: 1600 kg'));
        expect(text, contains('Series: 3'));
        expect(text, contains('- Sentadilla: 2 series'));
        expect(text, contains('- Press banca: 1 serie'));
        expect(text, isNot(contains('Buen progreso')));
        expect(text, isNot(contains('u1')));
      },
    );

    test('propaga el origen para anclar la hoja en iPad', () async {
      final sharer = FakeWorkoutSummarySharer();
      final viewModel = WorkoutDetailViewModel(
        repository: FakeWorkoutsRepository(sessions: [fakeSession()]),
        sessionId: 'actual',
        sharer: sharer,
      );
      const origin = Rect.fromLTWH(4, 8, 12, 16);

      await viewModel.load();
      await viewModel.shareSummary(origin: origin);

      expect(sharer.calls.single.origin, origin);
    });

    test('cancelar no deja error ni estado de compartir', () async {
      final sharer = FakeWorkoutSummarySharer(
        result: WorkoutShareResult.dismissed,
      );
      final viewModel = WorkoutDetailViewModel(
        repository: FakeWorkoutsRepository(sessions: [fakeSession()]),
        sessionId: 'actual',
        sharer: sharer,
      );

      await viewModel.load();
      await viewModel.shareSummary();

      expect(viewModel.actionError, isNull);
      expect(viewModel.sharing, isFalse);
    });

    test('un error muestra un mensaje neutro', () async {
      final sharer = FakeWorkoutSummarySharer(error: StateError('interno'));
      final viewModel = WorkoutDetailViewModel(
        repository: FakeWorkoutsRepository(sessions: [fakeSession()]),
        sessionId: 'actual',
        sharer: sharer,
      );

      await viewModel.load();
      await viewModel.shareSummary();

      expect(viewModel.actionError, workoutShareFailedMessage);
      expect(viewModel.sharing, isFalse);
    });

    test('no comparte dos veces mientras la hoja está abierta', () async {
      final sharer = GatedWorkoutSummarySharer();
      final viewModel = WorkoutDetailViewModel(
        repository: FakeWorkoutsRepository(sessions: [fakeSession()]),
        sessionId: 'actual',
        sharer: sharer,
      );

      await viewModel.load();
      final first = viewModel.shareSummary();
      final second = viewModel.shareSummary();

      expect(sharer.calls, 1);
      expect(viewModel.sharing, isTrue);

      sharer.gate.complete(WorkoutShareResult.shared);
      await Future.wait([first, second]);

      expect(viewModel.sharing, isFalse);
    });
  });

  group('repetir como borrador', () {
    test('conserva ejercicio, orden, peso y repeticiones sin rutina', () async {
      final viewModel = WorkoutDetailViewModel(
        repository: FakeWorkoutsRepository(sessions: [repeatableSession()]),
        sessionId: 'actual',
      );

      await viewModel.load();
      final draft = viewModel.repeatDraft()!;

      expect(draft.routineId, isNull);
      expect(draft.exercises.map((item) => item.exerciseId), ['ej-a', 'ej-b']);
      expect(draft.exercises.map((item) => item.position), [0, 1]);
      expect(
        draft.sets!.map(
          (set) => (set.exerciseId, set.order, set.weightKg, set.reps),
        ),
        [('ej-a', 1, 100.0, 5), ('ej-a', 2, 110.0, 3), ('ej-b', 3, 60.0, 10)],
      );
      expect(draft.toCreateWorkoutPayload(), {
        'startedAt': draft.startedAt.toUtc().toIso8601String(),
        'sets': [
          {'exerciseId': 'ej-a', 'order': 1, 'weight': 100.0, 'reps': 5},
          {'exerciseId': 'ej-a', 'order': 2, 'weight': 110.0, 'reps': 3},
          {'exerciseId': 'ej-b', 'order': 3, 'weight': 60.0, 'reps': 10},
        ],
      });
    });

    test('sin series identificables informa que no se puede repetir', () async {
      final viewModel = WorkoutDetailViewModel(
        repository: FakeWorkoutsRepository(sessions: [fakeSession()]),
        sessionId: 'actual',
      );

      await viewModel.load();

      expect(viewModel.repeatDraft(), isNull);
      expect(viewModel.actionError, workoutRepeatUnavailableMessage);
    });

    test(
      'si falta el identificador en una serie no repite parcialmente',
      () async {
        final viewModel = WorkoutDetailViewModel(
          repository: FakeWorkoutsRepository(
            sessions: [
              fakeSession(
                sets: const [
                  WorkoutSet(
                    exerciseId: 'ej-a',
                    exerciseName: 'Sentadilla',
                    order: 1,
                    weightKg: 100,
                    reps: 5,
                  ),
                  WorkoutSet(
                    exerciseName: 'Sentadilla',
                    order: 2,
                    weightKg: 100,
                    reps: 5,
                  ),
                ],
              ),
            ],
          ),
          sessionId: 'actual',
        );

        await viewModel.load();

        expect(viewModel.repeatDraft(), isNull);
        expect(viewModel.actionError, workoutRepeatUnavailableMessage);
      },
    );
  });

  group('sesión no disponible', () {
    test('un 404 descarta el resumen previo y no ofrece comparación', () async {
      final repository = FakeWorkoutsRepository(sessions: [fakeSession()]);
      final viewModel = WorkoutDetailViewModel(
        repository: repository,
        sessionId: 'actual',
      );

      await viewModel.load();
      expect(viewModel.notFound, isFalse);
      expect(viewModel.summary.dataOrNull, isNotNull);

      repository.getError = const WorkoutNotFoundException();
      await viewModel.load();

      expect(viewModel.notFound, isTrue);
      expect(viewModel.summary, isA<AsyncError>());
      expect(viewModel.summary.dataOrNull, isNull);
      expect(viewModel.comparison, isA<AsyncEmpty>());
    });

    test('no repite la solicitud mientras la carga está en curso', () async {
      final repository = GatedWorkoutsRepository(sessions: [fakeSession()]);
      final viewModel = WorkoutDetailViewModel(
        repository: repository,
        sessionId: 'actual',
      );

      final first = viewModel.load();
      final second = viewModel.load();

      expect(repository.calls, 1);
      repository.gate.complete();
      await Future.wait([first, second]);

      await viewModel.load();
      expect(repository.calls, 2);
    });
  });
}
