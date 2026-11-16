/// Entidad de demostracion para la nivelacion T3.
///
/// Representa un alimento del dominio de comidas de FitTrack360 sin acoplarse
/// a MealEntry ni al repositorio HTTP real.
class ComidaDemo {
  const ComidaDemo({
    required this.nombre,
    required this.tipo,
    required this.calorias,
  });

  /// Nombre del alimento (p. ej. "Avena con fruta").
  final String nombre;

  /// Tipo de comida del dia (desayuno, comida, cena, snack).
  final String tipo;

  /// Energia aproximada en kcal.
  final int calorias;
}
