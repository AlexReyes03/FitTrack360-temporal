/// Tiempo de comida. [apiValue] coincide con el enum MealType del API.
enum MealType {
  breakfast('BREAKFAST', 'Desayuno'),
  lunch('LUNCH', 'Comida'),
  dinner('DINNER', 'Cena'),
  snack('SNACK', 'Colación');

  const MealType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MealType fromApi(String value) => MealType.values.firstWhere(
    (type) => type.apiValue == value,
    orElse: () => MealType.snack,
  );
}
