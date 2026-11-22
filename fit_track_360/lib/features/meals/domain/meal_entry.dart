import 'macros.dart';
import 'meal_item.dart';
import 'meal_type.dart';

/// Comida registrada (MealLog) con sus alimentos.
class MealEntry {
  MealEntry({
    required this.id,
    required this.mealType,
    required this.eatenAt,
    required List<MealItem> items,
    this.isLegacy = false,
  }) : items = List.unmodifiable(items),
       macros = Macros.sum(items.map((item) => item.macros));

  final String id;
  final MealType mealType;
  final DateTime eatenAt;
  final List<MealItem> items;

  /// Suma de los macros congelados de [items].
  final Macros macros;

  /// Registro anterior a MealItem: el alimento se leyó de `notes`. El API no
  /// lo cuenta en sus totales porque no tiene items.
  final bool isLegacy;

  /// El legacy sin porción decodificable no se puede convertir sin perder los
  /// valores originales.
  bool get canEdit =>
      !isLegacy || (items.length == 1 && items.single.servingG > 0);
}

/// Datos para agregar un alimento a la comida de destino.
class NewMealEntry {
  const NewMealEntry({
    required this.mealType,
    required this.eatenAt,
    required this.name,
    required this.portionG,
    required this.macros,
    this.fdcId,
  });

  final MealType mealType;
  final DateTime eatenAt;
  final String name;
  final double portionG;
  final Macros macros;

  /// Identificador USDA FDC; null en captura manual.
  final String? fdcId;

  /// MealItem a persistir con los macros de la porción.
  MealItem get item =>
      MealItem(fdcId: fdcId, name: name, servingG: portionG, macros: macros);
}
