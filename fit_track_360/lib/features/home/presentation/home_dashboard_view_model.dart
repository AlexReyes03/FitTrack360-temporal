import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_today.dart';
import '../domain/steps_sensor.dart';
import 'widgets/dashboard_metric_card.dart';
import 'widgets/dashboard_nutrition_card.dart';
import 'widgets/dashboard_session_card.dart';
import 'widgets/dashboard_steps_card.dart';

/// Meta local de pasos (no viene del API del dashboard).
const int kDefaultDailyStepsGoal = 8000;

/// ViewModel del dashboard de Inicio: un [AsyncState] por bloque.
class HomeDashboardViewModel extends ChangeNotifier {
  HomeDashboardViewModel({
    required this._repository,
    this._stepsSensor,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DashboardRepository _repository;
  final StepsSensor? _stepsSensor;
  final DateTime Function() _now;

  bool _disposed = false;
  StreamSubscription<StepsSnapshot>? _stepsSubscription;

  AsyncState<DashboardNutritionData> _nutrition = const AsyncLoading();
  AsyncState<DashboardSessionData> _session = const AsyncLoading();
  AsyncState<DashboardMetricData> _metric = const AsyncLoading();
  AsyncState<DashboardStepsData> _steps = const AsyncLoading();
  bool _stepsUnavailable = false;
  bool _sessionExpired = false;

  AsyncState<DashboardNutritionData> get nutrition => _nutrition;
  AsyncState<DashboardSessionData> get session => _session;
  AsyncState<DashboardMetricData> get metric => _metric;
  AsyncState<DashboardStepsData> get steps => _steps;
  bool get stepsUnavailable => _stepsUnavailable;
  bool get sessionExpired => _sessionExpired;

  /// Carga el resumen remoto y arranca el sensor de pasos si aún no corre.
  Future<void> load() async {
    _sessionExpired = false;
    _nutrition = const AsyncLoading();
    _session = const AsyncLoading();
    _metric = const AsyncLoading();
    _notify();

    _ensureStepsListening();

    final now = _now();
    final local = now.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final utcOffsetMinutes = local.timeZoneOffset.inMinutes;

    try {
      final today = await _repository.today(
        date: date,
        utcOffsetMinutes: utcOffsetMinutes,
      );
      if (_disposed) return;
      _applyToday(today);
    } on SessionExpiredException catch (error, stackTrace) {
      _sessionExpired = true;
      _nutrition = AsyncError(error, stackTrace);
      _session = AsyncError(error, stackTrace);
      _metric = AsyncError(error, stackTrace);
      _notify();
    } catch (error, stackTrace) {
      if (_disposed) return;
      _nutrition = AsyncError(error, stackTrace);
      _session = AsyncError(error, stackTrace);
      _metric = AsyncError(error, stackTrace);
      _notify();
      if (error is! Exception) rethrow;
    }
  }

  void _applyToday(DashboardToday today) {
    final nutrition = today.nutrition;
    if (!nutrition.hasMeals) {
      _nutrition = const AsyncEmpty();
    } else {
      _nutrition = AsyncData(_mapNutrition(nutrition));
    }

    final session = today.session;
    if (session == null) {
      _session = const AsyncEmpty();
    } else {
      _session = AsyncData(_mapSession(session));
    }

    final metric = today.latestMetric;
    if (metric == null || !metric.hasDisplayValue) {
      _metric = const AsyncEmpty();
    } else {
      _metric = AsyncData(_mapMetric(metric, _now()));
    }
    _notify();
  }

  void _ensureStepsListening() {
    if (_stepsSubscription != null) return;
    final sensor = _stepsSensor;
    if (sensor == null) {
      _stepsUnavailable = true;
      _steps = AsyncData(
        const DashboardStepsData(
          stepsCount: 0,
          goalSteps: kDefaultDailyStepsGoal,
          subtitle: 'Meta diaria de actividad',
        ),
      );
      _notify();
      return;
    }

    _steps = const AsyncLoading();
    _stepsUnavailable = false;
    _notify();

    _stepsSubscription = sensor.watchDailySteps().listen(
      (snapshot) {
        if (_disposed) return;
        if (snapshot.unavailable) {
          _stepsUnavailable = true;
          _steps = AsyncData(
            const DashboardStepsData(
              stepsCount: 0,
              goalSteps: kDefaultDailyStepsGoal,
              subtitle: 'Meta diaria de actividad',
            ),
          );
        } else {
          _stepsUnavailable = false;
          _steps = AsyncData(
            DashboardStepsData(
              stepsCount: snapshot.steps,
              goalSteps: kDefaultDailyStepsGoal,
              subtitle: snapshot.steps == 0
                  ? 'Todavía no se registran pasos en el día de hoy.'
                  : 'Meta diaria de actividad',
            ),
          );
        }
        _notify();
      },
      onError: (_) {
        if (_disposed) return;
        _stepsUnavailable = true;
        _steps = AsyncData(
          const DashboardStepsData(
            stepsCount: 0,
            goalSteps: kDefaultDailyStepsGoal,
            subtitle: 'Meta diaria de actividad',
          ),
        );
        _notify();
      },
    );
  }

  static DashboardNutritionData _mapNutrition(DayNutrition nutrition) {
    return DashboardNutritionData(
      consumedKcal: nutrition.consumed.calories.round(),
      targetKcal: nutrition.goals.dailyCalorieGoal,
      proteinGrams: nutrition.consumed.proteinG.round(),
      proteinTargetGrams: nutrition.goals.proteinGoalG,
      carbsGrams: nutrition.consumed.carbsG.round(),
      carbsTargetGrams: nutrition.goals.carbsGoalG,
      fatGrams: nutrition.consumed.fatG.round(),
      fatTargetGrams: nutrition.goals.fatGoalG,
    );
  }

  static DashboardSessionData _mapSession(DaySession session) {
    final started = session.startedAt.toLocal();
    final notes = session.notes?.trim();
    final title = (notes != null && notes.isNotEmpty)
        ? notes
        : (session.isToday ? 'Sesión de hoy' : 'Última sesión');

    final relativeDate = session.isToday
        ? 'Hoy · ${_hhmm(started)}'
        : _formatDayMonth(started);

    final String summary;
    final ended = session.endedAt?.toLocal();
    if (ended == null) {
      summary = 'Sesión en curso';
    } else {
      final mins = ended.difference(started).inMinutes;
      summary = mins > 0
          ? 'Duración aproximada: $mins min'
          : 'Sesión registrada';
    }

    return DashboardSessionData(
      title: title,
      relativeDate: relativeDate,
      summary: summary,
      ctaLabel: ended == null
          ? 'Continuar entrenamiento'
          : 'Abrir entrenamiento',
    );
  }

  static DashboardMetricData _mapMetric(LatestBodyMetric metric, DateTime now) {
    final measured = metric.measuredAt.toLocal();
    if (metric.weightKg != null) {
      return DashboardMetricData(
        weightValue: _oneDecimal(metric.weightKg!),
        unit: 'kg',
        recordedAtLabel: _relativeDayLabel(measured, now),
        deltaLabel: 'Último registro corporal',
      );
    }
    if (metric.bodyFatPercent != null) {
      return DashboardMetricData(
        weightValue: _oneDecimal(metric.bodyFatPercent!),
        unit: '%',
        recordedAtLabel: _relativeDayLabel(measured, now),
        deltaLabel: 'Grasa corporal registrada',
      );
    }
    return DashboardMetricData(
      weightValue: _oneDecimal(metric.waistCm!),
      unit: 'cm',
      recordedAtLabel: _relativeDayLabel(measured, now),
      deltaLabel: 'Cintura registrada',
    );
  }

  static String _oneDecimal(double value) {
    final fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  static String _hhmm(DateTime local) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatDayMonth(DateTime local) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${local.day} ${months[local.month - 1]} · ${_hhmm(local)}';
  }

  static String _relativeDayLabel(DateTime measured, DateTime now) {
    final mDay = DateTime(measured.year, measured.month, measured.day);
    final nDay = DateTime(now.year, now.month, now.day);
    final diff = nDay.difference(mDay).inDays;
    if (diff == 0) return 'Hoy · ${_formatDayMonth(measured)}';
    if (diff == 1) return 'Ayer · ${_formatDayMonth(measured)}';
    if (diff > 1 && diff < 7) {
      return 'Hace $diff días · ${_formatDayMonth(measured)}';
    }
    return _formatDayMonth(measured);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stepsSubscription?.cancel());
    _stepsSubscription = null;
    unawaited(_stepsSensor?.dispose() ?? Future<void>.value());
    super.dispose();
  }
}
