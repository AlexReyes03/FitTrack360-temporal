import '../domain/macros.dart';

/// Lectura de registros legacy, SOLO lectura.
///
/// Antes de MealItem (M-02), la app guardaba nombre, porción y macros en
/// `MealLog.notes` con este formato:
/// `Avena · 50 g · 190 kcal · P 6.5 g · C 34 g · G 3.5 g`.
/// Esos registros llegan del API con `items` vacío; [MealsApiRepository] los
/// decodifica aquí para no perder el historial. La escritura nueva va siempre
/// por `items`: no hay `encode` a propósito.
class MealNotesCodec {
  static final _pattern = RegExp(
    r'^(.*) · ([\d.]+) g · ([\d.]+) kcal · P ([\d.]+) g · C ([\d.]+) g · G ([\d.]+) g$',
  );

  static ({String name, double portionG, Macros macros}) decode(String? notes) {
    final text = notes?.trim() ?? '';
    final match = _pattern.firstMatch(text);
    if (match == null) {
      return (
        name: text.isEmpty ? 'Sin nombre' : text,
        portionG: 0,
        macros: Macros.zero,
      );
    }
    double g(int i) => double.parse(match.group(i)!);
    return (
      name: match.group(1)!,
      portionG: g(2),
      macros: Macros(kcal: g(3), proteinG: g(4), carbsG: g(5), fatG: g(6)),
    );
  }
}
