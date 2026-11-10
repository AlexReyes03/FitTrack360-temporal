/// Calorías y macronutrientes (gramos). Valor inmutable.
class Macros {
  const Macros({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  static const zero = Macros(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0);

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Macros operator +(Macros other) => Macros(
    kcal: kcal + other.kcal,
    proteinG: proteinG + other.proteinG,
    carbsG: carbsG + other.carbsG,
    fatG: fatG + other.fatG,
  );

  Macros scale(double factor) => Macros(
    kcal: kcal * factor,
    proteinG: proteinG * factor,
    carbsG: carbsG * factor,
    fatG: fatG * factor,
  );

  static Macros sum(Iterable<Macros> values) =>
      values.fold(zero, (total, value) => total + value);

  @override
  bool operator ==(Object other) =>
      other is Macros &&
      other.kcal == kcal &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG;

  @override
  int get hashCode => Object.hash(kcal, proteinG, carbsG, fatG);

  @override
  String toString() =>
      'Macros(kcal: $kcal, P: $proteinG, C: $carbsG, G: $fatG)';
}
