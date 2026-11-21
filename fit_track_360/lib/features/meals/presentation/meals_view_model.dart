import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../domain/daily_summary.dart';
import '../domain/local_day.dart';
import '../domain/macros.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_item.dart';
import '../domain/meals_repository.dart';

enum MealMutationResult { success, notFound, failure, busy }

/// Resumen diario de consumidos (W11-FE-04.1, W12-18).
class MealsViewModel extends ChangeNotifier {
  MealsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MealsRepository _repository;
  final DateTime Function() _now;
  bool _disposed = false;
  bool _busy = false;

  AsyncState<DailySummary> _state = const AsyncLoading();
  AsyncState<DailySummary> get state => _state;

  /// La vista bloquea las acciones mientras hay una escritura en curso.
  bool get busy => _busy;

  /// La vista navega a `/login` cuando se vuelve true.
  bool _sessionExpired = false;
  bool get sessionExpired => _sessionExpired;

  Future<void> load() async {
    _set(const AsyncLoading());
    final now = _now();
    try {
      final entries = await _repository.list();
      final totals = await _dayTotalsOrNull(LocalDay.of(now));
      final summary = DailySummary.forDay(
        now,
        entries,
        persistedItemTotals: totals,
      );
      _set(summary.isEmpty ? const AsyncEmpty() : AsyncData(summary));
    } on SessionExpiredException catch (error, stackTrace) {
      _sessionExpired = true;
      _set(AsyncError(error, stackTrace));
    } catch (error, stackTrace) {
      _set(AsyncError(error, stackTrace));
      if (error is! Exception) rethrow;
    }
  }

  /// Totales persistidos del día local; si el resumen falla por otra causa,
  /// el dominio suma los registros (null).
  Future<Macros?> _dayTotalsOrNull(LocalDay day) async {
    try {
      return await _repository.dayTotals(day);
    } on SessionExpiredException {
      rethrow;
    } on Exception {
      return null;
    }
  }

  /// Agrega el alimento a su comida de destino y recarga el resumen.
  /// Devuelve false si ya hay una escritura en curso o el API rechazó el alta.
  /// La sesión expirada no se traga: marca [sessionExpired] para que la vista
  /// vaya a `/login`.
  Future<bool> add(NewMealEntry entry) async =>
      await _mutate(() => _repository.add(entry)) == MealMutationResult.success;

  /// Edita el item [index] de [entry] enviando el arreglo completo.
  Future<MealMutationResult> updateItem(
    MealEntry entry,
    int index,
    MealItem item,
  ) {
    if (index < 0 || index >= entry.items.length) {
      return Future.value(MealMutationResult.failure);
    }
    final items = [...entry.items]..[index] = item;
    return _mutate(() => _repository.update(entry.id, items));
  }

  /// Elimina el item [index]. Si era el último, elimina la comida completa
  /// para no dejar un MealLog vacío.
  Future<MealMutationResult> removeItem(MealEntry entry, int index) {
    if (index < 0 || index >= entry.items.length) {
      return Future.value(MealMutationResult.failure);
    }
    if (entry.items.length == 1) {
      return _mutate(() => _repository.delete(entry.id));
    }
    final items = [...entry.items]..removeAt(index);
    return _mutate(() => _repository.update(entry.id, items));
  }

  Future<MealMutationResult> _mutate(Future<void> Function() action) async {
    if (_busy) return MealMutationResult.busy;
    _busy = true;
    _notify();
    var result = MealMutationResult.success;
    try {
      try {
        await action();
      } on SessionExpiredException {
        _sessionExpired = true;
        result = MealMutationResult.failure;
      } on MealNotFoundException {
        result = MealMutationResult.notFound;
      } on Exception {
        result = MealMutationResult.failure;
      }
      if (!_disposed && result != MealMutationResult.failure) await load();
    } finally {
      _busy = false;
      _notify();
    }
    return result;
  }

  void _set(AsyncState<DailySummary> value) {
    _state = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
