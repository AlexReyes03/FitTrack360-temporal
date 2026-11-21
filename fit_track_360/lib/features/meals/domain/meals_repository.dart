import 'local_day.dart';
import 'macros.dart';
import 'meal_entry.dart';
import 'meal_item.dart';

/// El registro de comida ya no existe en el API.
class MealNotFoundException implements Exception {
  const MealNotFoundException();
}

abstract interface class MealsRepository {
  Future<List<MealEntry>> list();

  Future<MealEntry> add(NewMealEntry entry);

  /// Totales de los MealItem persistidos en [day] (día local).
  Future<Macros> dayTotals(LocalDay day);

  /// Reemplaza los items de la comida. El contrato del API no admite editar
  /// un item individual: se envía siempre el arreglo completo.
  Future<MealEntry> update(String mealId, List<MealItem> items);

  /// Elimina la comida completa y sus items.
  Future<void> delete(String mealId);
}
