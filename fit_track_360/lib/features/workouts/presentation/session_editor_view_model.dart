import 'package:flutter/foundation.dart';

import '../domain/workout_session_draft.dart';

/// Serie editable del registro manual: guarda el texto tal como se escribe
/// para poder marcar el error en el campo sin convertirlo a 0 o -1.
class EditableSessionSet {
  EditableSessionSet({
    required this.id,
    this.repsText = '',
    this.weightText = '0',
  });

  final String id;
  String repsText;
  String weightText;
  bool repsTouched = false;
  bool weightTouched = false;
}

/// Ejercicio del registro manual con sus series.
class EditableExerciseBlock {
  EditableExerciseBlock({
    required this.exerciseId,
    required this.name,
    required List<EditableSessionSet> sets,
  }) : sets = [...sets];

  final String exerciseId;
  final String name;
  final List<EditableSessionSet> sets;
}

/// Ejercicio quitado, para poder restaurarlo con «Deshacer».
class RemovedExercise {
  const RemovedExercise._(this.index, this.block);

  final int index;
  final EditableExerciseBlock block;
}

/// ViewModel del editor de series de un registro manual o una edición.
class SessionEditorViewModel extends ChangeNotifier {
  SessionEditorViewModel({WorkoutSessionDraft? initial}) {
    if (initial != null) _loadDraft(initial);
  }

  static const int maxReps = 1000;
  static const double maxWeightKg = 1000;
  static const double weightStep = 2.5;

  final List<EditableExerciseBlock> _blocks = [];
  int _nextId = 0;
  bool _showAllErrors = false;
  bool _dirty = false;
  bool _disposed = false;

  List<EditableExerciseBlock> get blocks => List.unmodifiable(_blocks);

  /// true cuando la persona cambió algo respecto a lo que se cargó.
  bool get dirty => _dirty;

  bool get isValid {
    for (final block in _blocks) {
      for (final set in block.sets) {
        if (_repsError(set.repsText) != null) return false;
        if (_weightError(set.weightText) != null) return false;
      }
    }
    return true;
  }

  /// Muestra los errores de todos los campos, aunque no se hayan tocado.
  void revealErrors() {
    _showAllErrors = true;
    _notify();
  }

  String? repsError(int block, int set) {
    final item = _blocks[block].sets[set];
    if (!_showAllErrors && !item.repsTouched) return null;
    return _repsError(item.repsText);
  }

  String? weightError(int block, int set) {
    final item = _blocks[block].sets[set];
    if (!_showAllErrors && !item.weightTouched) return null;
    return _weightError(item.weightText);
  }

  void addExercise({required String exerciseId, required String name}) {
    _blocks.add(
      EditableExerciseBlock(
        exerciseId: exerciseId,
        name: name,
        sets: [EditableSessionSet(id: _newId(), repsText: '10')],
      ),
    );
    _changed();
  }

  RemovedExercise removeExercise(int index) {
    final block = _blocks.removeAt(index);
    _changed();
    return RemovedExercise._(index, block);
  }

  void restoreExercise(RemovedExercise removed) {
    final index = removed.index.clamp(0, _blocks.length);
    _blocks.insert(index, removed.block);
    _changed();
  }

  void addSet(int block) {
    final sets = _blocks[block].sets;
    final last = sets.isEmpty ? null : sets.last;
    sets.add(
      EditableSessionSet(
        id: _newId(),
        repsText: last?.repsText ?? '10',
        weightText: last?.weightText ?? '0',
      ),
    );
    _changed();
  }

  void removeSet(int block, int set) {
    final sets = _blocks[block].sets;
    if (sets.length <= 1) return;
    sets.removeAt(set);
    _changed();
  }

  void setReps(int block, int set, String value) {
    final item = _blocks[block].sets[set];
    item
      ..repsText = value
      ..repsTouched = true;
    _changed();
  }

  void setWeight(int block, int set, String value) {
    final item = _blocks[block].sets[set];
    item
      ..weightText = value
      ..weightTouched = true;
    _changed();
  }

  void incrementReps(int block, int set) {
    final current = int.tryParse(_blocks[block].sets[set].repsText) ?? 0;
    setReps(block, set, '${(current + 1).clamp(1, maxReps)}');
  }

  void decrementReps(int block, int set) {
    final current = int.tryParse(_blocks[block].sets[set].repsText) ?? 0;
    setReps(block, set, current <= 1 ? '1' : '${current - 1}');
  }

  void incrementWeight(int block, int set) {
    final current = _parseWeight(_blocks[block].sets[set].weightText) ?? 0;
    final next = (current + weightStep).clamp(0, maxWeightKg).toDouble();
    setWeight(block, set, formatWeight(next));
  }

  void decrementWeight(int block, int set) {
    final current = _parseWeight(_blocks[block].sets[set].weightText) ?? 0;
    final next = current - weightStep;
    setWeight(block, set, formatWeight(next <= 0 ? 0 : next));
  }

  /// Ejercicios en el orden actual (solo tiene sentido si [isValid]).
  List<PlannedExercise> get exercises => [
    for (var i = 0; i < _blocks.length; i++)
      PlannedExercise(
        exerciseId: _blocks[i].exerciseId,
        exerciseName: _blocks[i].name,
        position: i,
        targetSets: _blocks[i].sets.length,
        targetReps: int.tryParse(_blocks[i].sets.first.repsText) ?? 1,
      ),
  ];

  /// Series con orden global consecutivo (solo tiene sentido si [isValid]).
  List<PlannedSet> get sets {
    var order = 0;
    return [
      for (final block in _blocks)
        for (final set in block.sets)
          PlannedSet(
            exerciseId: block.exerciseId,
            order: ++order,
            weightKg: _parseWeight(set.weightText) ?? 0,
            reps: int.tryParse(set.repsText) ?? 0,
          ),
    ];
  }

  void _loadDraft(WorkoutSessionDraft draft) {
    final ordered = [...draft.exercises]
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final exercise in ordered) {
      final exact = draft.sets
          ?.where((s) => s.exerciseId == exercise.exerciseId)
          .toList();
      final sets = exact != null && exact.isNotEmpty
          ? [
              for (final set in exact)
                EditableSessionSet(
                  id: _newId(),
                  repsText: '${set.reps}',
                  weightText: formatWeight(set.weightKg),
                ),
            ]
          : [
              for (var i = 0; i < exercise.targetSets; i++)
                EditableSessionSet(
                  id: _newId(),
                  repsText: '${exercise.targetReps}',
                ),
            ];
      _blocks.add(
        EditableExerciseBlock(
          exerciseId: exercise.exerciseId,
          name: exercise.exerciseName.isEmpty
              ? 'Ejercicio ${exercise.exerciseId}'
              : exercise.exerciseName,
          sets: sets.isEmpty
              ? [EditableSessionSet(id: _newId(), repsText: '10')]
              : sets,
        ),
      );
    }
  }

  String _newId() => 'set-${_nextId++}';

  static String? _repsError(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 'Indica las repeticiones';
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > maxReps) {
      return 'De 1 a $maxReps';
    }
    return null;
  }

  static String? _weightError(String raw) {
    if (raw.trim().isEmpty) return null; // Vacío = peso corporal (0 kg).
    final value = _parseWeight(raw);
    if (value == null || value < 0 || value > maxWeightKg) {
      return 'De 0 a ${maxWeightKg.toInt()} kg';
    }
    return null;
  }

  static double? _parseWeight(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  static String formatWeight(double value) {
    if (value == value.roundToDouble()) return '${value.toInt()}';
    return value.toStringAsFixed(value * 10 == (value * 10).round() ? 1 : 2);
  }

  void _changed() {
    _dirty = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
