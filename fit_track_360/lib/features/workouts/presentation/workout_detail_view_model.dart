import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../data/share_plus_workout_summary_sharer.dart';
import '../data/workout_session.dart';
import '../domain/repeat_session_as_draft.dart';
import '../domain/workout_not_found_exception.dart';
import '../domain/workout_session_draft.dart';
import '../domain/workout_summary.dart';
import '../domain/workout_summary_sharer.dart';
import '../domain/workouts_repository.dart';
import 'workout_share_text.dart';

const workoutNotFoundMessage = 'Esta sesión no está disponible';
const workoutShareFailedMessage = 'No se pudo compartir el resumen.';
const workoutRepeatUnavailableMessage =
    'Esta sesión no tiene series para repetir.';

/// Estado del detalle de una sesión. El resumen y la comparación se cargan
/// por separado: si no hay sesión previa o la comparación falla, el resumen
/// se muestra igual.
class WorkoutDetailViewModel extends ChangeNotifier {
  WorkoutDetailViewModel({
    required this._repository,
    required this.sessionId,
    WorkoutSummarySharer? sharer,
    DateTime Function()? clock,
  }) : _sharer = sharer ?? SharePlusWorkoutSummarySharer(),
       _repeat = RepeatSessionAsDraft(clock: clock);

  final WorkoutsRepository _repository;
  final WorkoutSummarySharer _sharer;
  final RepeatSessionAsDraft _repeat;
  final String sessionId;

  AsyncState<WorkoutSummary> _summary = const AsyncLoading();
  AsyncState<WorkoutComparison> _comparison = const AsyncLoading();
  WorkoutSession? _session;
  bool _loading = false;
  bool _notFound = false;
  bool _sharing = false;
  bool _sessionExpired = false;
  String? _actionError;
  bool _disposed = false;

  AsyncState<WorkoutSummary> get summary => _summary;

  /// [AsyncEmpty] cuando no existe una sesión anterior con la cual comparar.
  AsyncState<WorkoutComparison> get comparison => _comparison;

  WorkoutSession? get session => _session;

  bool get notFound => _notFound;

  bool get sharing => _sharing;

  String? get actionError => _actionError;

  /// True si el refresh falló; la vista debe mandar a login.
  bool get sessionExpired => _sessionExpired;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _session = null;
    _notFound = false;
    _actionError = null;
    _summary = const AsyncLoading();
    _comparison = const AsyncLoading();
    _notify();

    try {
      final session = await _repository.getById(sessionId);
      _session = session;
      final current = WorkoutSummary.of(session);
      _summary = AsyncData(current);
      _notify();

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
    } on WorkoutNotFoundException catch (error, stackTrace) {
      _notFound = true;
      _summary = AsyncError(error, stackTrace);
      _comparison = const AsyncEmpty();
    } on SessionExpiredException {
      _expire();
      return;
    } catch (error, stackTrace) {
      _summary = AsyncError(error, stackTrace);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> shareSummary({Rect? origin}) async {
    if (_sharing) return;
    final summary = _summary.dataOrNull;
    if (summary == null) return;

    _sharing = true;
    _actionError = null;
    _notify();
    try {
      await _sharer.shareText(
        text: buildWorkoutShareText(summary),
        origin: origin,
      );
    } catch (_) {
      _actionError = workoutShareFailedMessage;
    } finally {
      _sharing = false;
      _notify();
    }
  }

  WorkoutSessionDraft? repeatDraft() {
    final session = _session;
    if (session == null) return null;

    _actionError = null;
    try {
      final draft = _repeat(session);
      _notify();
      return draft;
    } on WorkoutSessionNotRepeatableException {
      _actionError = workoutRepeatUnavailableMessage;
      _notify();
      return null;
    }
  }

  void _expire() {
    _sessionExpired = true;
    _notify();
  }

  /// La vista puede desmontarse mientras hay una petición en curso; tras
  /// `dispose` no se notifica.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
