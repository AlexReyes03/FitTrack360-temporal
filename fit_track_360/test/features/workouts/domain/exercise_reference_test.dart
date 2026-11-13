import 'package:fit_track_360/features/workouts/domain/exercise_reference.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 11, 12, 10);

ExerciseSetRecord _set({
  String exerciseId = 'squat',
  int? order = 1,
  double? weightKg = 60,
  int reps = 10,
}) {
  return ExerciseSetRecord(
    exerciseId: exerciseId,
    order: order,
    weightKg: weightKg,
    reps: reps,
  );
}

ExerciseHistorySession _session({
  required String id,
  required DateTime startedAt,
  bool completed = true,
  List<ExerciseSetRecord> sets = const [],
}) {
  return ExerciseHistorySession(
    sessionId: id,
    startedAt: startedAt,
    endedAt: completed ? startedAt.add(const Duration(minutes: 50)) : null,
    sets: sets,
  );
}

PreviousSetReference? _lookup(
  List<ExerciseHistorySession> sessions, {
  String exerciseId = 'squat',
  int? order = 1,
}) {
  return findPreviousSetReference(
    sessions: sessions,
    exerciseId: exerciseId,
    currentSessionId: 'current',
    currentStartedAt: _now,
    equivalent: (set) => set.order == order,
  );
}

void main() {
  test('elige la sesión completada más reciente con el ejercicio', () {
    final reference = _lookup([
      _session(
        id: 'old',
        startedAt: _now.subtract(const Duration(days: 7)),
        sets: [_set(weightKg: 50)],
      ),
      _session(
        id: 'recent',
        startedAt: _now.subtract(const Duration(days: 1)),
        sets: [_set(weightKg: 60, reps: 8)],
      ),
      _session(
        id: 'other',
        startedAt: _now.subtract(const Duration(hours: 2)),
        sets: [_set(exerciseId: 'bench', weightKg: 80)],
      ),
    ]);

    expect(reference, isNotNull);
    expect(reference!.weightKg, 60);
    expect(reference.reps, 8);
    expect(reference.performedAt, _now.subtract(const Duration(days: 1)));
  });

  test('excluye la sesión actual', () {
    final reference = _lookup([
      _session(
        id: 'current',
        startedAt: _now.subtract(const Duration(minutes: 5)),
        sets: [_set(weightKg: 70)],
      ),
    ]);

    expect(reference, isNull);
  });

  test('excluye sesiones posteriores o simultáneas', () {
    final reference = _lookup([
      _session(
        id: 'future',
        startedAt: _now.add(const Duration(hours: 1)),
        sets: [_set()],
      ),
      _session(id: 'same', startedAt: _now, sets: [_set()]),
    ]);

    expect(reference, isNull);
  });

  test('ignora sesiones sin terminar y usa la anterior completada', () {
    final reference = _lookup([
      _session(
        id: 'open',
        startedAt: _now.subtract(const Duration(hours: 1)),
        completed: false,
        sets: [_set(weightKg: 70)],
      ),
      _session(
        id: 'closed',
        startedAt: _now.subtract(const Duration(days: 1)),
        sets: [_set(weightKg: 55)],
      ),
    ]);

    expect(reference?.weightKg, 55);
  });

  test('devuelve null sin historial', () {
    expect(_lookup(const []), isNull);
  });

  test('no recurre a sesiones más antiguas si falta la serie equivalente', () {
    final reference = _lookup([
      _session(
        id: 'recent',
        startedAt: _now.subtract(const Duration(days: 1)),
        sets: [_set(order: 2, weightKg: 65)],
      ),
      _session(
        id: 'old',
        startedAt: _now.subtract(const Duration(days: 5)),
        sets: [_set(order: 1, weightKg: 50)],
      ),
    ]);

    expect(reference, isNull);
  });

  test('no usa series de otro ejercicio', () {
    final reference = _lookup([
      _session(
        id: 'recent',
        startedAt: _now.subtract(const Duration(days: 1)),
        sets: [_set(exerciseId: 'bench')],
      ),
    ]);

    expect(reference, isNull);
  });

  test('elige la serie equivalente dentro de la sesión', () {
    final reference = _lookup([
      _session(
        id: 'past',
        startedAt: _now.subtract(const Duration(days: 1)),
        sets: [_set(order: 1, weightKg: 60), _set(order: 2, weightKg: 65)],
      ),
    ], order: 2);

    expect(reference?.weightKg, 65);
  });

  test('conserva el peso nulo y el cero sin interpretarlos', () {
    final withoutWeight = _lookup([
      _session(
        id: 'a',
        startedAt: _now.subtract(const Duration(days: 1)),
        sets: [_set(weightKg: null, reps: 12)],
      ),
    ]);
    final zero = _lookup([
      _session(
        id: 'b',
        startedAt: _now.subtract(const Duration(days: 1)),
        sets: [_set(weightKg: 0)],
      ),
    ]);

    expect(withoutWeight?.weightKg, isNull);
    expect(withoutWeight?.reps, 12);
    expect(zero?.weightKg, 0);
  });

  test('la equivalencia la define el llamador, no order', () {
    final reference = findPreviousSetReference(
      sessions: [
        _session(
          id: 'past',
          startedAt: _now.subtract(const Duration(days: 1)),
          sets: [_set(order: null, reps: 9)],
        ),
      ],
      exerciseId: 'squat',
      currentSessionId: 'current',
      currentStartedAt: _now,
      equivalent: (set) => set.reps == 9,
    );

    expect(reference?.reps, 9);
  });
}
