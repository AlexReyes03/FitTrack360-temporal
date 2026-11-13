import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../domain/daily_summary.dart';
import '../domain/meal_entry.dart';
import '../domain/meals_repository.dart';

/// Resumen diario de consumidos (W11-FE-04.1).
class MealsViewModel extends ChangeNotifier {
  MealsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MealsRepository _repository;
  final DateTime Function() _now;

  AsyncState<DailySummary> _state = const AsyncLoading();
  AsyncState<DailySummary> get state => _state;

  Future<void> load() async {
    _set(const AsyncLoading());
    try {
      final entries = await _repository.list();
      final summary = DailySummary.forDay(_now(), entries);
      _set(summary.isEmpty ? const AsyncEmpty() : AsyncData(summary));
    } catch (error, stackTrace) {
      _set(AsyncError(error, stackTrace));
      if (error is! Exception) rethrow;
    }
  }

  /// Agrega el alimento a su comida de destino y recarga el resumen.
  /// Devuelve false si el API rechazó el alta.
  Future<bool> add(NewMealEntry entry) async {
    try {
      await _repository.add(entry);
    } on Exception {
      return false;
    }
    await load();
    return true;
  }

  void _set(AsyncState<DailySummary> value) {
    _state = value;
    notifyListeners();
  }
}
