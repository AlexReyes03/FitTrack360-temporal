import 'macros.dart';

/// Alimento dentro de una comida (MealItem del API). Sus macros quedan
/// congelados al registrarse (regla M-02): no se recalculan desde USDA.
class MealItem {
  const MealItem({
    this.id,
    this.fdcId,
    required this.name,
    required this.servingG,
    required this.macros,
  });

  /// Identificador del MealItem en el API; null antes de persistirse.
  final String? id;

  /// Identificador USDA FDC como texto; null en captura manual.
  final String? fdcId;
  final String name;

  /// Porción consumida en gramos.
  final double servingG;

  /// Macros de la porción consumida.
  final Macros macros;
}
