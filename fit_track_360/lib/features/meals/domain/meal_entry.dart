import 'macros.dart';
import 'meal_type.dart';

/// Alimento registrado en una comida del usuario.
class MealEntry {
  const MealEntry({
    required this.id,
    required this.mealType,
    required this.eatenAt,
    required this.name,
    required this.portionG,
    required this.macros,
  });

  final String id;
  final MealType mealType;
  final DateTime eatenAt;
  final String name;
  final double portionG;
  final Macros macros;
}

/// Datos para agregar un alimento a la comida de destino.
class NewMealEntry {
  const NewMealEntry({
    required this.mealType,
    required this.eatenAt,
    required this.name,
    required this.portionG,
    required this.macros,
  });

  final MealType mealType;
  final DateTime eatenAt;
  final String name;
  final double portionG;
  final Macros macros;
}
