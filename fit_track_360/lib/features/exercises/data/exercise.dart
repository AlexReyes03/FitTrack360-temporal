/// Ejercicio del catálogo (`GET /api/v1/exercises`).
///
/// Prisma solo persiste `id`, `name`, `imageFile`, `gifFile`, `attribution`,
/// `bodyPart`, `equipment` y `target`. Instrucciones y músculos existen en el
/// seed pero aún no en la base (W11-01), y `nameEs`, `level` y `commonErrors`
/// no existen en ninguna capa. La UI omite los campos ausentes.
class Exercise {
  final String id;
  final String name;
  final String? nameEs;
  final String? category;
  final String bodyPart;
  final String equipment;
  final String target;
  final String? muscleGroup;
  final List<String> secondaryMuscles;
  final String? level;
  final String? instructionsEs;
  final List<String> instructionStepsEs;
  final String? commonErrors;

  /// Archivo en `/static/exercises/images`; si falta, se pinta un marcador.
  final String imageFile;

  /// Archivo en `/static/exercises/videos`; si falta, se usa la imagen JPG.
  final String gifFile;

  final String? mediaId;

  /// Leyenda de licencia de Gym Visual, tal como la entrega el API.
  final String attribution;

  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.attribution,
    this.imageFile = '',
    this.gifFile = '',
    this.nameEs,
    this.category,
    this.muscleGroup,
    this.secondaryMuscles = const <String>[],
    this.level,
    this.instructionsEs,
    this.instructionStepsEs = const <String>[],
    this.commonErrors,
    this.mediaId,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: _requiredString(json['id'], 'id'),
      name: _requiredString(json['name'], 'name'),
      nameEs: _optionalString(json['nameEs']),
      category: _optionalString(json['category']),
      bodyPart: _requiredString(json['bodyPart'], 'bodyPart'),
      equipment: _requiredString(json['equipment'], 'equipment'),
      target: _requiredString(json['target'], 'target'),
      muscleGroup: _optionalString(json['muscleGroup']),
      secondaryMuscles: _stringList(json['secondaryMuscles']),
      level: _optionalString(json['level']),
      instructionsEs: _optionalString(json['instructionsEs']),
      instructionStepsEs: _stringList(json['instructionStepsEs']),
      commonErrors: _optionalString(json['commonErrors']),
      imageFile: _optionalString(json['imageFile']) ?? '',
      gifFile: _optionalString(json['gifFile']) ?? '',
      mediaId: _optionalString(json['mediaId']),
      attribution: _requiredString(json['attribution'], 'attribution'),
    );
  }
}

/// Página del catálogo; el sobre `{items, total, page, pageSize}` es provisional.
class ExercisePage {
  final List<Exercise> items;
  final int total;
  final int page;
  final int pageSize;

  const ExercisePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Acepta el sobre provisional y, como degradación, un array plano: en ese
  /// caso solo hay una página y `total` es la cantidad recibida.
  factory ExercisePage.fromJson(
    Object? json, {
    required int page,
    required int pageSize,
  }) {
    if (json is List) {
      final items = json.whereType<Map<String, dynamic>>().map(
        Exercise.fromJson,
      );
      final list = List<Exercise>.unmodifiable(items);
      return ExercisePage(
        items: list,
        total: list.length,
        page: page,
        pageSize: pageSize,
      );
    }

    if (json is Map<String, dynamic>) {
      final rawItems = json['items'];
      final items = rawItems is List
          ? List<Exercise>.unmodifiable(
              rawItems.whereType<Map<String, dynamic>>().map(Exercise.fromJson),
            )
          : const <Exercise>[];
      return ExercisePage(
        items: items,
        total: _positiveInt(json['total'], items.length),
        page: _positiveInt(json['page'], page),
        pageSize: _positiveInt(json['pageSize'], pageSize),
      );
    }

    throw const FormatException('Respuesta de ejercicios inválida');
  }

  int get totalPages {
    if (pageSize <= 0) return 1;
    return (total / pageSize).ceil().clamp(1, 1 << 31);
  }

  bool get hasPrevious => page > 1;

  bool get hasNext => page < totalPages;
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('El campo "$field" del ejercicio es obligatorio');
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
  );
}

int _positiveInt(Object? value, int fallback) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0) return value.toInt();
  return fallback;
}
