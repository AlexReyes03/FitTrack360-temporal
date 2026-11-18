import 'local_day.dart';
import 'macros.dart';
import 'meal_entry.dart';

abstract interface class MealsRepository {
  Future<List<MealEntry>> list();

  Future<MealEntry> add(NewMealEntry entry);

  /// Totales de los MealItem persistidos en [day] (día local).
  Future<Macros> dayTotals(LocalDay day);
}
