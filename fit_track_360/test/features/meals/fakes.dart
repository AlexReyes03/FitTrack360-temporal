import 'package:fit_track_360/features/meals/domain/food_item.dart';
import 'package:fit_track_360/features/meals/domain/food_search_repository.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meals_repository.dart';

class FakeMealsRepository implements MealsRepository {
  final List<MealEntry> stored = [];
  Object? listError;

  @override
  Future<List<MealEntry>> list() async {
    if (listError != null) throw listError!;
    return List.of(stored);
  }

  @override
  Future<MealEntry> add(NewMealEntry entry) async {
    final created = MealEntry(
      id: 'id-${stored.length}',
      mealType: entry.mealType,
      eatenAt: entry.eatenAt,
      name: entry.name,
      portionG: entry.portionG,
      macros: entry.macros,
    );
    stored.add(created);
    return created;
  }
}

class FakeFoodSearchRepository implements FoodSearchRepository {
  final List<String> queries = [];
  List<FoodItem> results = const [];
  Object? error;

  @override
  Future<List<FoodItem>> search(String query) async {
    queries.add(query);
    if (error != null) throw error!;
    return results;
  }
}
