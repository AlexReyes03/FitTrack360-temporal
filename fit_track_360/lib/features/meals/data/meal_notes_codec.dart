import '../domain/macros.dart';

/// Puente temporal: el modelo MealLog del API aún no tiene MealItem
/// (plan §MealItem). Mientras tanto, nombre, porción y macros viajan en
/// `notes` con un formato legible y reversible:
/// `Avena · 50 g · 190 kcal · P 6.5 g · C 34 g · G 3.5 g`.
class MealNotesCodec {
  static final _pattern = RegExp(
    r'^(.*) · ([\d.]+) g · ([\d.]+) kcal · P ([\d.]+) g · C ([\d.]+) g · G ([\d.]+) g$',
  );

  static String encode(String name, double portionG, Macros macros) =>
      '${name.trim()} · ${_n(portionG)} g · ${_n(macros.kcal)} kcal · '
      'P ${_n(macros.proteinG)} g · C ${_n(macros.carbsG)} g · '
      'G ${_n(macros.fatG)} g';

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

  /// Hasta una décima, sin ceros sobrantes.
  static String _n(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
  }
}
