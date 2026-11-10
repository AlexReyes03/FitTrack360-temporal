import 'meal_entry.dart';

abstract interface class MealsRepository {
  Future<List<MealEntry>> list();

  Future<MealEntry> add(NewMealEntry entry);
}
