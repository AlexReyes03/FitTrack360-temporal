import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../data/workout_session.dart';
import '../domain/workout_summary.dart';
import '../domain/workouts_repository.dart';

/// Estado del detalle de una sesión. El resumen y la comparación se cargan
/// por separado: si no hay sesión previa o la comparación falla, el resumen
/// se muestra igual.
class WorkoutDetailViewModel extends ChangeNotifier {
  WorkoutDetailViewModel({required this._repository, required this.sessionId});

  final WorkoutsRepository _repository;
  final String sessionId;

  AsyncState<WorkoutSummary> _summary = const AsyncLoading();
  AsyncState<WorkoutComparison> _comparison = const AsyncLoading();
  bool _sessionExpired = false;

  AsyncState<WorkoutSummary> get summary => _summary;

  /// [AsyncEmpty] cuando no existe una sesión anterior con la cual comparar.
  AsyncState<WorkoutComparison> get comparison => _comparison;

  /// True si el refresh falló; la vista debe mandar a login.
  bool get sessionExpired => _sessionExpired;

  Future<void> load() async {
    _summary = const AsyncLoading();
    _comparison = const AsyncLoading();
    notifyListeners();

    final WorkoutSession session;
    try {
      session = await _repository.getById(sessionId);
    } on SessionExpiredException {
      _expire();
      return;
    } catch (error, stackTrace) {
      _summary = AsyncError(error, stackTrace);
      notifyListeners();
      return;
    }
    final current = WorkoutSummary.of(session);
    _summary = AsyncData(current);
    notifyListeners();

    try {
      final previous = findPreviousSession(await _repository.list(), session);
      _comparison = previous == null
          ? const AsyncEmpty()
          : AsyncData(
              WorkoutComparison.between(current, WorkoutSummary.of(previous)),
            );
    } on SessionExpiredException {
      _expire();
      return;
    } catch (error, stackTrace) {
      _comparison = AsyncError(error, stackTrace);
    }
    notifyListeners();
  }

  void _expire() {
    _sessionExpired = true;
    notifyListeners();
  }
}
