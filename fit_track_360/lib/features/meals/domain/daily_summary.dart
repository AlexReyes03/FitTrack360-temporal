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
  DailySummary._(this.day, this.sections)
    : totals = Macros.sum(sections.map((section) => section.totals));

  /// Filtra [entries] al día local de [day] y agrupa en las cuatro secciones.
  factory DailySummary.forDay(DateTime day, Iterable<MealEntry> entries) {
    final ofDay = entries.where((entry) => _sameDay(entry.eatenAt, day));
    return DailySummary._(
      DateTime(day.year, day.month, day.day),
      List.unmodifiable([
        for (final type in MealType.values)
          MealSection(
            type,
            ofDay.where((entry) => entry.mealType == type).toList(),
          ),
      ]),
    );
  }

  final DateTime day;
  final List<MealSection> sections;
  final Macros totals;

  bool get isEmpty => sections.every((section) => section.entries.isEmpty);

  MealSection sectionFor(MealType type) =>
      sections.firstWhere((section) => section.mealType == type);

  static bool _sameDay(DateTime a, DateTime b) {
    final local = a.toLocal();
    return local.year == b.year && local.month == b.month && local.day == b.day;
  }
}
