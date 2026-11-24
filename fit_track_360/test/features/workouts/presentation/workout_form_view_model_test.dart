import 'package:fit_track_360/features/workouts/data/workout_session.dart';
import 'package:fit_track_360/features/workouts/data/workouts_api.dart';
import 'package:fit_track_360/features/workouts/domain/workout_session_draft.dart';
import 'package:fit_track_360/features/workouts/presentation/workout_form_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_workouts_repository.dart';

class _RecordingApi implements WorkoutsApi {
  final created = <WorkoutSessionDraft>[];
  final updates = <Map<String, dynamic>>[];

  @override
  Future<WorkoutSession> create(WorkoutSessionDraft draft) async {
    created.add(draft);
    return fakeSession();
  }

  @override
  Future<WorkoutSession> update(String id, Map<String, dynamic> payload) async {
    updates.add(payload);
    return fakeSession();
  }

  @override
  Future<WorkoutSession> createWithPayload(Map<String, dynamic> payload) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<WorkoutSession> getById(String id) => throw UnimplementedError();
  @override
  Future<List<WorkoutSession>> list() async => const [];
}

final _now = DateTime(2026, 11, 20, 7, 30);

WorkoutFormViewModel _vm(_RecordingApi api, {WorkoutSession? editing}) {
  final vm = WorkoutFormViewModel(
    api: api,
    editingSession: editing,
    now: () => _now,
  );
  addTearDown(vm.dispose);
  return vm;
}

void main() {
  test(
    'un registro pasado se guarda finalizado con inicio + duración',
    () async {
      final api = _RecordingApi();
      final vm = _vm(api);
      vm.editor.addExercise(exerciseId: '0001', name: 'Sentadilla');
      vm.setDuration('45');

      final result = await vm.save();

      expect(result, WorkoutFormSaveResult.saved);
      final draft = api.created.single;
      expect(draft.startedAt, _now);
      expect(draft.endedAt, _now.add(const Duration(minutes: 45)));
      expect(
        draft.toCreateWorkoutPayload()['endedAt'],
        _now.add(const Duration(minutes: 45)).toUtc().toIso8601String(),
      );
    },
  );

  test('editar una sesión sin fin exige la duración y envía endedAt', () async {
    final api = _RecordingApi();
    final vm = _vm(api, editing: repeatableSession());
    expect(vm.durationText, '60');

    final legacy = _vm(
      api,
      editing: fakeSession(duration: null, sets: const []),
    );
    expect(legacy.durationText, isEmpty);
    expect(await legacy.save(), WorkoutFormSaveResult.invalid);
    expect(legacy.durationError, 'Indica cuánto duró el entrenamiento');
    expect(api.updates, isEmpty);

    legacy.setDuration('30');
    expect(await legacy.save(), WorkoutFormSaveResult.saved);
    expect(api.updates.single['endedAt'], isNotNull);
  });

  test('cada campo muestra su propio error y no se envía nada', () async {
    final api = _RecordingApi();
    final vm = _vm(api);
    vm.editor.addExercise(exerciseId: '0001', name: 'Sentadilla');
    vm.editor.setReps(0, 0, '');
    vm.setDuration('');
    vm.setRest('');

    expect(await vm.save(), WorkoutFormSaveResult.invalid);

    expect(vm.durationError, isNotNull);
    expect(vm.restError, 'De 0 a 900 segundos');
    expect(vm.editor.repsError(0, 0), 'Indica las repeticiones');
    expect(vm.editor.weightError(0, 0), isNull);
    expect(api.created, isEmpty);
  });

  test('antes de guardar, un campo sin tocar no muestra error', () {
    final vm = _vm(_RecordingApi());
    vm.editor.addExercise(exerciseId: '0001', name: 'Sentadilla');

    expect(vm.durationError, isNull);
    expect(vm.restError, isNull);
    expect(vm.editor.repsError(0, 0), isNull);
  });

  test('el descanso del perfil no pisa lo que la persona escribió', () {
    final vm = _vm(_RecordingApi());
    expect(vm.restText, '90');

    vm.setRest('45');
    vm.applyProfileRest(120);

    expect(vm.restText, '45');
  });

  test('el descanso del perfil se aplica si no se ha editado', () {
    final vm = _vm(_RecordingApi());

    vm.applyProfileRest(120);

    expect(vm.restText, '120');
    expect(vm.dirty, isFalse);
  });

  test('dirty solo cuando hay cambios', () {
    final vm = _vm(_RecordingApi());
    expect(vm.dirty, isFalse);

    vm.setNotes('Pierna');
    expect(vm.dirty, isTrue);
  });

  test('agregar un ejercicio también marca cambios', () {
    final vm = _vm(_RecordingApi());

    vm.editor.addExercise(exerciseId: '0001', name: 'Sentadilla');

    expect(vm.dirty, isTrue);
  });
}
