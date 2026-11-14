/// Resumen de rutina para el listado. Es un modelo de lectura: no sustituye
/// al `Routine` de dominio compartido con las demás subtareas.
class RoutineSummary {
  final String id;
  final String name;
  final String? notes;

  /// `null` cuando la respuesta no incluye los ejercicios.
  final int? exerciseCount;

  /// Suma de las series objetivo; `null` si no hay ese dato.
  final int? targetSetCount;

  const RoutineSummary({
    required this.id,
    required this.name,
    this.notes,
    this.exerciseCount,
    this.targetSetCount,
  });

  factory RoutineSummary.fromJson(Map<String, dynamic> json) {
    final exercises = _exerciseItems(json['exercises']);
    return RoutineSummary(
      id: json['id'] as String,
      name: _optionalText(json['name']) ?? '',
      notes: _optionalText(json['notes']),
      exerciseCount: exercises?.length,
      targetSetCount: exercises == null ? null : _sumTargetSets(exercises),
    );
  }
}

/// Detalle de una rutina con sus ejercicios en el orden recibido.
class RoutineDetail {
  final String id;
  final String name;
  final String? notes;
  final List<RoutineExerciseSummary> exercises;

  const RoutineDetail({
    required this.id,
    required this.name,
    this.notes,
    this.exercises = const [],
  });

  factory RoutineDetail.fromJson(Map<String, dynamic> json) {
    final items = _exerciseItems(json['exercises']) ?? const [];
    final exercises = items
        .map(RoutineExerciseSummary.fromJson)
        .toList(growable: false);
    final ordered = [...exercises]..sort(_byPosition);
    return RoutineDetail(
      id: json['id'] as String,
      name: _optionalText(json['name']) ?? '',
      notes: _optionalText(json['notes']),
      exercises: List.unmodifiable(ordered),
    );
  }
}

/// Ejercicio dentro del detalle, con sus objetivos opcionales.
class RoutineExerciseSummary {
  final String? exerciseId;
  final String? exerciseName;
  final int? position;
  final int? targetSets;
  final int? targetReps;

  const RoutineExerciseSummary({
    this.exerciseId,
    this.exerciseName,
    this.position,
    this.targetSets,
    this.targetReps,
  });

  factory RoutineExerciseSummary.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercise'];
    final nestedName = exercise is Map<String, dynamic>
        ? _optionalText(exercise['name'])
        : null;
    return RoutineExerciseSummary(
      exerciseId: _optionalText(json['exerciseId']),
      exerciseName: _optionalText(json['exerciseName']) ?? nestedName,
      position: _asInt(json['position']),
      targetSets: _asInt(json['targetSets']),
      targetReps: _asInt(json['targetReps']),
    );
  }

  String get displayName => exerciseName ?? 'Ejercicio';

  /// Objetivo legible solo con los datos presentes.
  String? get targetLabel {
    final sets = targetSets;
    final reps = targetReps;
    if (sets == null && reps == null) return null;
    final setsText = sets == null
        ? null
        : '$sets ${sets == 1 ? 'serie' : 'series'}';
    final repsText = reps == null
        ? null
        : '$reps ${reps == 1 ? 'rep' : 'reps'}';
    if (setsText != null && repsText != null) return '$setsText × $repsText';
    return setsText ?? repsText;
  }
}

/// Lectura de rutinas. La implementación real puede cambiar sin tocar la UI.
abstract interface class RoutinesReader {
  Future<List<RoutineSummary>> list();

  Future<RoutineDetail> getById(String id);
}

class RoutineNotFoundException implements Exception {
  const RoutineNotFoundException();

  @override
  String toString() => 'Rutina no encontrada';
}

List<Map<String, dynamic>>? _exerciseItems(Object? value) {
  if (value is! List) return null;
  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}

int? _sumTargetSets(List<Map<String, dynamic>> items) {
  final values = items
      .map((item) => _asInt(item['targetSets']))
      .whereType<int>();
  if (values.isEmpty) return null;
  return values.fold<int>(0, (total, value) => total + value);
}

int? _asInt(Object? value) => value is num ? value.toInt() : null;

String? _optionalText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

int _byPosition(RoutineExerciseSummary a, RoutineExerciseSummary b) {
  final positionA = a.position;
  final positionB = b.position;
  if (positionA == null && positionB == null) return 0;
  if (positionA == null) return 1;
  if (positionB == null) return -1;
  return positionA.compareTo(positionB);
}
