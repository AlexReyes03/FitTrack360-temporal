import 'dart:async';

import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/meals/domain/food_item.dart';
import 'package:fit_track_360/features/meals/domain/food_search_repository.dart';
import 'package:fit_track_360/features/meals/domain/local_day.dart';
import 'package:fit_track_360/features/meals/domain/macros.dart';
import 'package:fit_track_360/features/meals/domain/meal_entry.dart';
import 'package:fit_track_360/features/meals/domain/meal_item.dart';
import 'package:fit_track_360/features/meals/domain/meals_repository.dart';

class FakeMealsRepository implements MealsRepository {
  final List<MealEntry> stored = [];
  final List<LocalDay> totalsRequests = [];
  final List<({String mealId, List<MealItem> items})> updates = [];
  final List<String> deletes = [];
  Object? listError;
  Object? addError;
  Object? updateError;
  Object? deleteError;
  Object? totalsError;
  int listCalls = 0;

  /// Si no es null, `list` espera a que se complete (pruebas de dispose).
  Completer<void>? listGate;
  Completer<void>? updateGate;
  Completer<void>? deleteGate;

  @override
  Future<List<MealEntry>> list() async {
    listCalls++;
    if (listGate != null) await listGate!.future;
    if (listError != null) throw listError!;
    return List.of(stored);
  }

  @override
  Future<MealEntry> add(NewMealEntry entry) async {
    if (addError != null) throw addError!;
    final created = MealEntry(
      id: 'id-${stored.length}',
      mealType: entry.mealType,
      eatenAt: entry.eatenAt,
      items: [entry.item],
    );
    stored.add(created);
    return created;
  }

  @override
  Future<MealEntry> update(String mealId, List<MealItem> items) async {
    updates.add((mealId: mealId, items: List.of(items)));
    if (updateGate != null) await updateGate!.future;
    if (updateError != null) throw updateError!;
    final index = stored.indexWhere((entry) => entry.id == mealId);
    if (index < 0) throw const MealNotFoundException();
    final current = stored[index];
    final updated = MealEntry(
      id: current.id,
      mealType: current.mealType,
      eatenAt: current.eatenAt,
      items: items,
    );
    stored[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String mealId) async {
    deletes.add(mealId);
    if (deleteGate != null) await deleteGate!.future;
    if (deleteError != null) throw deleteError!;
    final index = stored.indexWhere((entry) => entry.id == mealId);
    if (index < 0) throw const MealNotFoundException();
    stored.removeAt(index);
  }

  /// Igual que el API: solo suma los MealItem persistidos (no los legacy).
  @override
  Future<Macros> dayTotals(LocalDay day) async {
    totalsRequests.add(day);
    if (totalsError != null) throw totalsError!;
    return Macros.sum(
      stored
          .where((entry) => !entry.isLegacy && day.contains(entry.eatenAt))
          .map((entry) => entry.macros),
    );
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

class FakeSessionStorage implements SessionStorage {
  String? accessToken = 'access';

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      forceRefresh ? null : accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async => this.accessToken = accessToken;

  @override
  Future<void> clear() async => accessToken = null;
}
