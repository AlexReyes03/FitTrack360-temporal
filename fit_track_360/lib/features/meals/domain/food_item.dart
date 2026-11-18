import 'macros.dart';

/// Alimento del catálogo (USDA vía proxy). [macros] corresponden a
/// [baseServingG] gramos (USDA normaliza a 100 g).
class FoodItem {
  const FoodItem({
    this.fdcId,
    required this.name,
    required this.baseServingG,
    required this.macros,
  });

  final int? fdcId;
  final String name;
  final double baseServingG;
  final Macros macros;

  /// Macros para una porción de [grams] gramos.
  Macros forPortion(double grams) {
    if (grams <= 0 || baseServingG <= 0) return Macros.zero;
    return macros.scale(grams / baseServingG);
  }
}
