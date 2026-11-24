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
  StepsUnavailableReason? _stepsUnavailableReason;
  bool _stepsNeedPermission = false;
  bool _stepsInitialized = false;
  bool _sessionExpired = false;

  /// Folio de la última llamada a [load]; descarta respuestas viejas.
  int _loadSequence = 0;

  AsyncState<DashboardNutritionData> get nutrition => _nutrition;
  AsyncState<DashboardSessionData> get session => _session;
  AsyncState<DashboardMetricData> get metric => _metric;
  AsyncState<DashboardStepsData> get steps => _steps;
  bool get stepsUnavailable => _stepsUnavailable;
  StepsUnavailableReason? get stepsUnavailableReason => _stepsUnavailableReason;

  /// El bloque de pasos espera la acción «Mostrar mis pasos» del usuario.
  bool get stepsNeedPermission => _stepsNeedPermission;

  /// El sistema ya no vuelve a preguntar: solo queda abrir Ajustes.
  bool get stepsCanOpenSettings =>
      _stepsUnavailable &&
      _stepsUnavailableReason == StepsUnavailableReason.blocked;
  bool get sessionExpired => _sessionExpired;

  /// Carga el resumen remoto. La primera vez prepara el bloque de pasos sin
  /// mostrar diálogos del sistema (el permiso se pide en contexto).
  Future<void> load() => _fetch(keepVisible: false);

  /// Recarga sin esqueletos: los bloques con datos o vacíos se quedan a la
  /// vista hasta que llega la respuesta (pull-to-refresh y volver a Inicio).
  /// Un bloque en error sí vuelve a mostrar la carga.
  Future<void> refresh() => _fetch(keepVisible: true);

  Future<void> _fetch({required bool keepVisible}) async {
    final sequence = ++_loadSequence;
    _sessionExpired = false;
    _nutrition = _loadingUnlessVisible(_nutrition, keepVisible);
    _session = _loadingUnlessVisible(_session, keepVisible);
    _metric = _loadingUnlessVisible(_metric, keepVisible);
    _notify();

    unawaited(_initSteps());

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
      if (_isStale(sequence)) return;
      _applyToday(today);
    } on SessionExpiredException catch (error, stackTrace) {
      if (_isStale(sequence)) return;
      _sessionExpired = true;
      _nutrition = AsyncError(error, stackTrace);
      _session = AsyncError(error, stackTrace);
      _metric = AsyncError(error, stackTrace);
      _notify();
    } catch (error, stackTrace) {
      if (_isStale(sequence)) return;
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

  static AsyncState<T> _loadingUnlessVisible<T>(
    AsyncState<T> current,
    bool keepVisible,
  ) {
    if (keepVisible && (current is AsyncData<T> || current is AsyncEmpty<T>)) {
      return current;
    }
    return AsyncLoading<T>();
  }

  bool _isStale(int sequence) => _disposed || sequence != _loadSequence;

  Future<void> _initSteps() async {
    if (_stepsInitialized) return;
    _stepsInitialized = true;
    final sensor = _stepsSensor;
    if (sensor == null) {
      _setStepsUnavailable(StepsUnavailableReason.sensorError);
      return;
    }
    bool ready;
    try {
      ready = await sensor.canReadWithoutPrompt();
    } catch (_) {
      ready = false;
    }
    // Si el usuario ya tocó «Mostrar mis pasos» mientras se consultaba, no
    // se pisa la lectura en curso.
    if (_disposed || _stepsSubscription != null) return;
    if (ready) {
      _listenSteps(sensor);
      return;
    }
    _stepsNeedPermission = true;
    _stepsUnavailable = false;
    _steps = const AsyncData(_stepsPlaceholder);
    _notify();
  }

  /// Acción «Mostrar mis pasos»: dispara el diálogo del sistema (en Android
  /// vía `permission_handler`; en iOS al escuchar CoreMotion).
  void enableSteps() {
    final sensor = _stepsSensor;
    if (_disposed || sensor == null) return;
    _listenSteps(sensor);
  }

  /// «Reintentar» del bloque de pasos: reinicia la lectura del sensor.
  void retrySteps() => enableSteps();

  Future<void> openStepsSettings() async {
    try {
      await _stepsSensor?.openSettings();
    } catch (_) {
      // Si el sistema no abre Ajustes, el bloque sigue con «Reintentar».
    }
  }

  void _listenSteps(StepsSensor sensor) {
    final previous = _stepsSubscription;
    _stepsSubscription = null;
    unawaited(previous?.cancel());

    _stepsNeedPermission = false;
    _stepsUnavailable = false;
    _stepsUnavailableReason = null;
    _steps = const AsyncLoading();
    _notify();

    _stepsSubscription = sensor.watchDailySteps().listen(
      (snapshot) {
        if (_disposed) return;
        if (snapshot.unavailable) {
          _setStepsUnavailable(
            snapshot.reason ?? StepsUnavailableReason.sensorError,
          );
          return;
        }
        _stepsUnavailable = false;
        _stepsUnavailableReason = null;
        _steps = AsyncData(
          DashboardStepsData(
            stepsCount: snapshot.steps,
            goalSteps: kDefaultDailyStepsGoal,
            subtitle: _stepsSubtitle(snapshot),
          ),
        );
        _notify();
      },
      onError: (_) {
        if (_disposed) return;
        _setStepsUnavailable(StepsUnavailableReason.sensorError);
      },
    );
  }

  void _setStepsUnavailable(StepsUnavailableReason reason) {
    _stepsNeedPermission = false;
    _stepsUnavailable = true;
    _stepsUnavailableReason = reason;
    _steps = const AsyncData(_stepsPlaceholder);
    _notify();
  }

  static const _stepsPlaceholder = DashboardStepsData(
    stepsCount: 0,
    goalSteps: kDefaultDailyStepsGoal,
    subtitle: 'Meta diaria de actividad',
  );

  /// El podómetro no guarda los pasos previos a la primera lectura del día,
  /// así que se indica honestamente desde qué hora se cuentan.
  static String _stepsSubtitle(StepsSnapshot snapshot) {
    final since = snapshot.countingSince?.toLocal();
    if (snapshot.steps == 0) {
      return since == null
          ? 'Todavía no se registran pasos en el día de hoy.'
          : 'Todavía no se registran pasos desde las ${_hhmm(since)}.';
    }
    return since == null
        ? 'Meta diaria de actividad'
        : 'Contados desde las ${_hhmm(since)} de hoy';
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

    // El tracker solo persiste la sesión al finalizar, así que una sesión del
    // API nunca está activa: sin `endedAt` es un registro sin duración (p. ej.
    // los guardados por el formulario antes de #228), no algo que continuar.
    final ended = session.endedAt?.toLocal();
    final mins = ended?.difference(started).inMinutes ?? 0;
    final summary = mins > 0
        ? 'Duración aproximada: $mins min'
        : 'Sesión registrada';

    return DashboardSessionData(
      title: title,
      relativeDate: relativeDate,
      summary: summary,
      ctaLabel: 'Abrir entrenamiento',
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
