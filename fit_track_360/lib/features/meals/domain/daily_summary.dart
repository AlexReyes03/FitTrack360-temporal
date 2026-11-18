import 'macros.dart';
import 'meal_entry.dart';
import 'meal_type.dart';

/// Sección del día para un tipo de comida.
class MealSection {
  MealSection(this.mealType, List<MealEntry> entries)
    : entries = List.unmodifiable(entries),
      totals = Macros.sum(entries.map((entry) => entry.macros));

  final MealType mealType;
  final List<MealEntry> entries;
  final Macros totals;
}

/// Resumen diario de consumidos agrupado por tipo de comida.
class DailySummary {
  DailySummary._(this.day, this.sections, this.totals);

  /// Filtra [entries] al día local de [day] y agrupa en las cuatro secciones.
  ///
  /// [persistedItemTotals] son los totales del día que calcula el API con los
  /// MealItem congelados. El API no ve los macros de los registros legacy
  /// (viven en `notes`), así que se suman aparte. Sin ese dato, el total es
  /// la suma de las secciones.
  factory DailySummary.forDay(
    DateTime day,
    Iterable<MealEntry> entries, {
    Macros? persistedItemTotals,
  }) {
    final ofDay = entries
        .where((entry) => _sameDay(entry.eatenAt, day))
        .toList();
    final sections = List<MealSection>.unmodifiable([
      for (final type in MealType.values)
        MealSection(
          type,
          ofDay.where((entry) => entry.mealType == type).toList(),
        ),
    ]);
    final totals = persistedItemTotals == null
        ? Macros.sum(sections.map((section) => section.totals))
        : persistedItemTotals +
              Macros.sum(
                ofDay
                    .where((entry) => entry.isLegacy)
                    .map((entry) => entry.macros),
              );
    final local = day.toLocal();
    return DailySummary._(
      DateTime(local.year, local.month, local.day),
      sections,
      totals,
    );
  }

  final DateTime day;
  final List<MealSection> sections;
  final Macros totals;

  bool get isEmpty => sections.every((section) => section.entries.isEmpty);

  MealSection sectionFor(MealType type) =>
      sections.firstWhere((section) => section.mealType == type);

  /// Simétrico: ambos instantes se normalizan a la hora local del
  /// dispositivo antes de comparar año, mes y día.
  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
