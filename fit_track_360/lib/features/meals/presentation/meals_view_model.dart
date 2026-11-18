import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../domain/daily_summary.dart';
import '../domain/local_day.dart';
import '../domain/macros.dart';
import '../domain/meal_entry.dart';
import '../domain/meals_repository.dart';

/// Resumen diario de consumidos (W11-FE-04.1, W12-18).
class MealsViewModel extends ChangeNotifier {
  MealsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MealsRepository _repository;
  final DateTime Function() _now;
  bool _disposed = false;

  AsyncState<DailySummary> _state = const AsyncLoading();
  AsyncState<DailySummary> get state => _state;

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
  /// Devuelve false si el API rechazó el alta. La sesión expirada no se
  /// traga: marca [sessionExpired] para que la vista vaya a `/login`.
  Future<bool> add(NewMealEntry entry) async {
    try {
      await _repository.add(entry);
    } on SessionExpiredException {
      _sessionExpired = true;
      _notify();
      return false;
    } on Exception {
      return false;
    }
    if (_disposed) return true;
    await load();
    return true;
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
