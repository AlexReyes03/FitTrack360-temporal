import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../domain/food_item.dart';
import '../domain/food_search_repository.dart';
import '../domain/macros.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_type.dart';

/// Búsqueda USDA con debounce, porción y comida de destino (W11-FE-04.3).
class FoodSearchViewModel extends ChangeNotifier {
  FoodSearchViewModel(
    this._repository, {
    this._destination = MealType.breakfast,
  });

  static const debounceDuration = Duration(milliseconds: 400);
  static const minQueryLength = 2;

  final FoodSearchRepository _repository;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  /// null mientras no hay búsqueda.
  AsyncState<List<FoodItem>>? _results;
  AsyncState<List<FoodItem>>? get results => _results;

  bool _sessionExpired = false;
  bool get sessionExpired => _sessionExpired;

  FoodItem? _selected;
  FoodItem? get selected => _selected;

  double _portionG = 100;
  double get portionG => _portionG;

  MealType _destination;
  MealType get destination => _destination;

  /// Sin resultados, error o timeout del proxy: se ofrece captura manual.
  bool get offersManualCapture =>
      _results is AsyncEmpty<List<FoodItem>> ||
      _results is AsyncError<List<FoodItem>>;

  Macros get selectedMacros => _selected?.forPortion(_portionG) ?? Macros.zero;

  void onQueryChanged(String query) {
    _debounce?.cancel();
    final term = query.trim();
    if (term.length < minQueryLength) {
      _requestId++;
      _results = null;
      _notify();
      return;
    }
    _debounce = Timer(debounceDuration, () => _search(term));
  }

  Future<void> _search(String term) async {
    final id = ++_requestId;
    _results = const AsyncLoading();
    _notify();
    try {
      final items = await _repository.search(term);
      if (id != _requestId) return;
      _results = AsyncState.fromData(items);
    } on SessionExpiredException {
      if (id != _requestId) return;
      _sessionExpired = true;
      _results = null;
    } catch (error, stackTrace) {
      if (id != _requestId) return;
      _results = AsyncError(error, stackTrace);
    }
    _notify();
  }

  void select(FoodItem? food) {
    _selected = food;
    _notify();
  }

  void setPortion(double grams) {
    _portionG = grams;
    _notify();
  }

  void setDestination(MealType type) {
    _destination = type;
    _notify();
  }

  /// Entrada para el alimento elegido; null si falta alimento o porción.
  NewMealEntry? buildEntry(DateTime eatenAt) {
    final food = _selected;
    if (food == null || _portionG <= 0) return null;
    return NewMealEntry(
      mealType: _destination,
      eatenAt: eatenAt,
      name: food.name,
      portionG: _portionG,
      macros: food.forPortion(_portionG),
    );
  }

  /// Captura manual: los macros son los de la porción capturada.
  /// null si falta nombre, la porción no es positiva o hay macros negativos.
  NewMealEntry? buildManualEntry({
    required String name,
    required double? portionG,
    required Macros? macros,
    required DateTime eatenAt,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || portionG == null || portionG <= 0) return null;
    if (macros == null ||
        [
          macros.kcal,
          macros.proteinG,
          macros.carbsG,
          macros.fatG,
        ].any((value) => value < 0)) {
      return null;
    }
    return NewMealEntry(
      mealType: _destination,
      eatenAt: eatenAt,
      name: trimmed,
      portionG: portionG,
      macros: macros,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
