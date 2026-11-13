/// Traducciones de `bodyPart`, `equipment` y `target` del dataset
/// (`fit_track_api/seed/exercises.es.json`). Un valor desconocido conserva el
/// texto original con la inicial en mayúscula; nunca se inventa una etiqueta.
library;

/// Valores de `bodyPart` del dataset (grupo muscular).
const List<String> bodyPartOptions = <String>[
  'back',
  'cardio',
  'chest',
  'lower arms',
  'lower legs',
  'neck',
  'shoulders',
  'upper arms',
  'upper legs',
  'waist',
];

/// Valores de `equipment` del dataset.
const List<String> equipmentOptions = <String>[
  'assisted',
  'band',
  'barbell',
  'body weight',
  'bosu ball',
  'cable',
  'dumbbell',
  'elliptical machine',
  'ez barbell',
  'hammer',
  'kettlebell',
  'leverage machine',
  'medicine ball',
  'olympic barbell',
  'resistance band',
  'roller',
  'rope',
  'skierg machine',
  'sled machine',
  'smith machine',
  'stability ball',
  'stationary bike',
  'stepmill machine',
  'tire',
  'trap bar',
  'upper body ergometer',
  'weighted',
  'wheel roller',
];

/// Valores de `target` del dataset (músculo objetivo).
const List<String> targetOptions = <String>[
  'abductors',
  'abs',
  'adductors',
  'biceps',
  'calves',
  'cardiovascular system',
  'delts',
  'forearms',
  'glutes',
  'hamstrings',
  'lats',
  'levator scapulae',
  'pectorals',
  'quads',
  'serratus anterior',
  'spine',
  'traps',
  'triceps',
  'upper back',
];

const Map<String, String> _bodyPartLabels = <String, String>{
  'back': 'Espalda',
  'cardio': 'Cardio',
  'chest': 'Pecho',
  'lower arms': 'Antebrazos',
  'lower legs': 'Pantorrillas',
  'neck': 'Cuello',
  'shoulders': 'Hombros',
  'upper arms': 'Brazos',
  'upper legs': 'Muslos',
  'waist': 'Cintura',
};

const Map<String, String> _equipmentLabels = <String, String>{
  'assisted': 'Asistido',
  'band': 'Banda',
  'barbell': 'Barra',
  'body weight': 'Peso corporal',
  'bosu ball': 'Bosu',
  'cable': 'Polea',
  'dumbbell': 'Mancuerna',
  'elliptical machine': 'Elíptica',
  'ez barbell': 'Barra EZ',
  'hammer': 'Martillo',
  'kettlebell': 'Pesa rusa',
  'leverage machine': 'Máquina de palanca',
  'medicine ball': 'Balón medicinal',
  'olympic barbell': 'Barra olímpica',
  'resistance band': 'Banda de resistencia',
  'roller': 'Rodillo',
  'rope': 'Cuerda',
  'skierg machine': 'Máquina SkiErg',
  'sled machine': 'Máquina de trineo',
  'smith machine': 'Máquina Smith',
  'stability ball': 'Balón de estabilidad',
  'stationary bike': 'Bicicleta estática',
  'stepmill machine': 'Escaladora',
  'tire': 'Llanta',
  'trap bar': 'Barra hexagonal',
  'upper body ergometer': 'Ergómetro de brazos',
  'weighted': 'Con peso',
  'wheel roller': 'Rueda abdominal',
};

const Map<String, String> _targetLabels = <String, String>{
  'abductors': 'Abductores',
  'abs': 'Abdominales',
  'adductors': 'Aductores',
  'biceps': 'Bíceps',
  'calves': 'Pantorrillas',
  'cardiovascular system': 'Sistema cardiovascular',
  'delts': 'Deltoides',
  'forearms': 'Antebrazos',
  'glutes': 'Glúteos',
  'hamstrings': 'Isquiotibiales',
  'lats': 'Dorsales',
  'levator scapulae': 'Elevador de la escápula',
  'pectorals': 'Pectorales',
  'quads': 'Cuádriceps',
  'serratus anterior': 'Serrato anterior',
  'spine': 'Columna',
  'traps': 'Trapecios',
  'triceps': 'Tríceps',
  'upper back': 'Espalda alta',
};

/// Vocabulario de `muscleGroup` y `secondaryMuscles` del dataset.
const Map<String, String> _muscleLabels = <String, String>{
  'abdominals': 'Abdominales',
  'ankle stabilizers': 'Estabilizadores del tobillo',
  'ankles': 'Tobillos',
  'back': 'Espalda',
  'brachialis': 'Braquial',
  'chest': 'Pecho',
  'core': 'Core',
  'deltoids': 'Deltoides',
  'feet': 'Pies',
  'grip muscles': 'Músculos de agarre',
  'groin': 'Ingle',
  'hands': 'Manos',
  'hip flexors': 'Flexores de cadera',
  'inner thighs': 'Muslo interno',
  'latissimus dorsi': 'Dorsal ancho',
  'lower abs': 'Abdominales bajos',
  'lower back': 'Espalda baja',
  'obliques': 'Oblicuos',
  'quadriceps': 'Cuádriceps',
  'rear deltoids': 'Deltoides posteriores',
  'rhomboids': 'Romboides',
  'rotator cuff': 'Manguito rotador',
  'shins': 'Tibiales',
  'soleus': 'Sóleo',
  'sternocleidomastoid': 'Esternocleidomastoideo',
  'trapezius': 'Trapecio',
  'upper chest': 'Pecho superior',
  'wrist extensors': 'Extensores de muñeca',
  'wrist flexors': 'Flexores de muñeca',
  'wrists': 'Muñecas',
};

/// Etiqueta en español de `bodyPart`.
String translateBodyPart(String value) =>
    _bodyPartLabels[value] ?? _humanize(value);

/// Etiqueta en español de `equipment`.
String translateEquipment(String value) =>
    _equipmentLabels[value] ?? _humanize(value);

/// Etiqueta en español de `target`.
String translateTarget(String value) =>
    _targetLabels[value] ?? _humanize(value);

/// Etiqueta de un músculo cualquiera de `muscleGroup` o `secondaryMuscles`,
/// que usan un vocabulario más amplio que `target`.
String translateMuscle(String value) =>
    _muscleLabels[value] ?? _targetLabels[value] ?? _humanize(value);

String _humanize(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}
