import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../domain/exercise_reference.dart';
import '../domain/tracker_finish_payload.dart';
import '../domain/tracker_location_provider.dart';
import '../domain/workouts_repository.dart';
import 'tracker_page.dart';
import 'widgets/tracker_location_section.dart';
import 'widgets/tracker_sets_section.dart';

/// Estado editable de una serie en la sesion activa.
class TrackerEditableSet {
  TrackerEditableSet({
    required this.id,
    required this.order,
    this.weightText = '',
    this.repsText = '',
    this.completed = false,
    this.previousReference,
    this.hasWeightError = false,
    this.hasRepsError = false,
  });

  final String id;
  int order;
  String weightText;
  String repsText;
  bool completed;
  PreviousSetReference? previousReference;
  bool hasWeightError;
  bool hasRepsError;

  TrackerSetItem toItem() => TrackerSetItem(
    id: id,
    order: order,
    weightText: weightText,
    repsText: repsText,
    completed: completed,
    previousReference: previousReference,
    hasWeightError: hasWeightError,
    hasRepsError: hasRepsError,
    errorText: _errorText,
  );

  String? get _errorText {
    final messages = [
      if (hasWeightError)
        'Peso: de 0 a ${TrackerViewModel.maxWeightKg.toInt()} kg',
      if (hasRepsError)
        'Repeticiones: entero de 1 a ${TrackerViewModel.maxReps}',
    ];
    return messages.isEmpty ? null : messages.join(' · ');
  }
}

/// ViewModel del tracker live: timers locales, series, P2 y persistencia.
class TrackerViewModel extends ChangeNotifier {
  TrackerViewModel({
    required this._repository,
    required this._locationProvider,
    required this.exerciseId,
    required this.exerciseName,
    this.exerciseTags = const [],
    this.instructionsText,
    DateTime Function()? now,
    this.initialSetCount = 3,
    this.restPresetSeconds = const [60, 90, 120],
    this.autoStartSessionTimer = true,
  }) : _now = now ?? DateTime.now,
       startedAt = (now ?? DateTime.now)(),
       selectedRestSeconds = 90,
       restRemaining = const Duration(seconds: 90) {
    _sets = [
      for (var i = 0; i < initialSetCount; i++)
        TrackerEditableSet(id: 'set-${i + 1}', order: i + 1),
    ];
    if (autoStartSessionTimer) {
      startSessionTimer();
    }
    unawaited(loadHistoryReferences());
  }

  /// Limites de captura. El API solo exige minimos (peso >= 0, reps >= 1);
  /// estos maximos evitan valores absurdos y no finitos antes de enviar.
  static const double maxWeightKg = 1000;
  static const int maxReps = 1000;

  final WorkoutsRepository _repository;
  final TrackerLocationProvider _locationProvider;
  final DateTime Function() _now;

  final String exerciseId;
  final String exerciseName;
  final List<String> exerciseTags;
  final String? instructionsText;
  final int initialSetCount;
  final List<int> restPresetSeconds;
  final bool autoStartSessionTimer;

  final DateTime startedAt;

  Timer? _sessionTimer;
  Timer? _restTimer;

  Duration _elapsed = Duration.zero;
  bool _sessionRunning = false;

  Duration restRemaining;
  bool _restRunning = false;
  int selectedRestSeconds;

  List<TrackerEditableSet> _sets = [];
  String notes = '';
  TrackerLocationMode locationMode = TrackerLocationMode.gps;
  String manualZone = '';
  String gpsStatusLabel = 'Sin ubicacion capturada todavia';
  String? capturedLocation;

  AsyncState<String> _finishState = const AsyncEmpty();
  bool _sessionExpired = false;
  bool _disposed = false;
  String? finishError;
  String? savedSessionId;

  List<ExerciseHistorySession> _history = const [];

  Duration get elapsed => _elapsed;
  bool get isSessionTimerRunning => _sessionRunning;
  bool get isRestRunning => _restRunning;
  List<TrackerSetItem> get setItems =>
      List.unmodifiable(_sets.map((set) => set.toItem()));
  AsyncState<String> get finishState => _finishState;
  bool get sessionExpired => _sessionExpired;

  TrackerExerciseData get exerciseData => TrackerExerciseData(
    name: exerciseName,
    tags: exerciseTags,
    progressLabel: 'Sesion en curso',
  );

  String get elapsedLabel => formatTrackerDuration(_elapsed);
  String get restRemainingLabel => formatTrackerDuration(restRemaining);

  void startSessionTimer() {
    if (_sessionRunning) return;
    _sessionRunning = true;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tickSessionSecond();
    });
    _notify();
  }

  /// Avanza un segundo del cronometro (tambien usable en pruebas).
  void tickSessionSecond() {
    if (!_sessionRunning) return;
    _elapsed += const Duration(seconds: 1);
    _notify();
  }

  void pauseSessionTimer() {
    if (!_sessionRunning) return;
    _sessionRunning = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _notify();
  }

  void toggleSessionTimer() {
    if (_sessionRunning) {
      pauseSessionTimer();
    } else {
      startSessionTimer();
    }
  }

  void resetSessionTimer() {
    pauseSessionTimer();
    _elapsed = Duration.zero;
    _notify();
  }

  void selectRestPreset(int seconds) {
    selectedRestSeconds = seconds;
    if (!_restRunning) {
      restRemaining = Duration(seconds: seconds);
    }
    _notify();
  }

  void startRestTimer() {
    if (_restRunning) return;
    if (restRemaining <= Duration.zero) {
      restRemaining = Duration(seconds: selectedRestSeconds);
    }
    _restRunning = true;
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tickRestSecond();
    });
    _notify();
  }

  /// Avanza un segundo del descanso (tambien usable en pruebas).
  void tickRestSecond() {
    if (!_restRunning) return;
    if (restRemaining <= const Duration(seconds: 1)) {
      restRemaining = Duration.zero;
      pauseRestTimer();
      return;
    }
    restRemaining -= const Duration(seconds: 1);
    _notify();
  }

  void pauseRestTimer() {
    if (!_restRunning) return;
    _restRunning = false;
    _restTimer?.cancel();
    _restTimer = null;
    _notify();
  }

  void toggleRestTimer() {
    if (_restRunning) {
      pauseRestTimer();
    } else {
      startRestTimer();
    }
  }

  void resetRestTimer() {
    pauseRestTimer();
    restRemaining = Duration(seconds: selectedRestSeconds);
    _notify();
  }

  void addSet() {
    final order = _sets.length + 1;
    _sets = [
      ..._sets,
      TrackerEditableSet(
        id: 'set-${_now().microsecondsSinceEpoch}-$order',
        order: order,
        previousReference: _referenceForOrder(order),
      ),
    ];
    _notify();
  }

  void removeSet(int index) {
    if (index < 0 || index >= _sets.length) return;
    if (_sets.length == 1) return;
    final next = [..._sets]..removeAt(index);
    for (var i = 0; i < next.length; i++) {
      next[i].order = i + 1;
      next[i].previousReference = _referenceForOrder(i + 1);
    }
    _sets = next;
    _notify();
  }

  void setWeightText(int index, String value) {
    if (!_validIndex(index)) return;
    _sets[index].weightText = value;
    _sets[index].hasWeightError = !_isValidWeight(value);
    _notify();
  }

  void setRepsText(int index, String value) {
    if (!_validIndex(index)) return;
    _sets[index].repsText = value;
    _sets[index].hasRepsError = !_isValidReps(value);
    _notify();
  }

  void incrementWeight(int index) {
    if (!_validIndex(index)) return;
    final current = _parseWeight(_sets[index].weightText) ?? 0;
    setWeightText(index, _formatNumber(current + 2.5));
  }

  void decrementWeight(int index) {
    if (!_validIndex(index)) return;
    final current = _parseWeight(_sets[index].weightText) ?? 0;
    final next = current - 2.5;
    setWeightText(index, next <= 0 ? '' : _formatNumber(next));
  }

  void incrementReps(int index) {
    if (!_validIndex(index)) return;
    final current = int.tryParse(_sets[index].repsText.trim()) ?? 0;
    setRepsText(index, '${current + 1}');
  }

  void decrementReps(int index) {
    if (!_validIndex(index)) return;
    final current = int.tryParse(_sets[index].repsText.trim()) ?? 0;
    final next = current - 1;
    setRepsText(index, next <= 0 ? '' : '$next');
  }

  void toggleSetCompleted(int index) {
    if (!_validIndex(index)) return;
    final set = _sets[index];
    if (!set.completed) {
      set.hasWeightError = !_isValidWeight(set.weightText);
      set.hasRepsError = !_isValidReps(set.repsText);
      if (set.hasWeightError || set.hasRepsError) {
        _notify();
        return;
      }
      set.completed = true;
      if (!_restRunning) {
        restRemaining = Duration(seconds: selectedRestSeconds);
        startRestTimer();
      }
    } else {
      set.completed = false;
    }
    _notify();
  }

  void updateNotes(String value) {
    notes = value;
    _notify();
  }

  void setLocationMode(TrackerLocationMode mode) {
    locationMode = mode;
    _notify();
  }

  void updateManualZone(String value) {
    manualZone = value;
    if (locationMode == TrackerLocationMode.manualZone) {
      capturedLocation = value.trim().isEmpty ? null : value.trim();
    }
    _notify();
  }

  Future<void> requestGpsLocation() async {
    gpsStatusLabel = 'Obteniendo ubicacion aproximada...';
    _notify();
    final fix = await _locationProvider.getApproximateLocation();
    if (fix == null) {
      gpsStatusLabel =
          'No se pudo obtener GPS. Usa zona manual o continua sin ubicacion.';
      locationMode = TrackerLocationMode.manualZone;
      capturedLocation = manualZone.trim().isEmpty ? null : manualZone.trim();
      _notify();
      return;
    }
    capturedLocation = fix.label;
    gpsStatusLabel = 'Ubicacion aproximada: ${fix.label}';
    locationMode = TrackerLocationMode.gps;
    _notify();
  }

  Future<void> loadHistoryReferences() async {
    try {
      final sessions = await _repository.list();
      _history = [
        for (final session in sessions)
          ExerciseHistorySession(
            sessionId: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            sets: [
              for (final set in session.sets)
                if (set.exerciseId != null)
                  ExerciseSetRecord(
                    exerciseId: set.exerciseId!,
                    order: set.order,
                    weightKg: set.weightKg,
                    reps: set.reps,
                  ),
            ],
          ),
      ];
      for (final set in _sets) {
        set.previousReference = _referenceForOrder(set.order);
      }
      _notify();
    } on SessionExpiredException {
      _sessionExpired = true;
      _notify();
    } catch (_) {
      // Sin historial no bloquea el tracker.
    }
  }

  /// Valida las series completadas y persiste la sesion. Devuelve el id
  /// creado o null. Las series pendientes no se validan ni se envian.
  Future<String?> finishSession() async {
    finishError = null;
    final payloadSets = <TrackerFinishSet>[];
    var hasError = false;
    var completedCount = 0;

    for (final set in _sets) {
      if (!set.completed) continue;
      completedCount++;
      final weightOk = _isValidWeight(set.weightText);
      final repsOk = _isValidReps(set.repsText);
      set.hasWeightError = !weightOk;
      set.hasRepsError = !repsOk;
      if (!weightOk || !repsOk) {
        hasError = true;
        continue;
      }
      payloadSets.add(
        TrackerFinishSet(
          exerciseId: exerciseId,
          order: payloadSets.length + 1,
          weightKg: _parseWeight(set.weightText) ?? 0,
          reps: int.parse(set.repsText.trim()),
        ),
      );
    }

    if (completedCount == 0 || hasError) {
      finishError = completedCount == 0
          ? 'Completa al menos una serie'
          : 'Corrige peso y repeticiones de las series completadas';
      _finishState = AsyncError(finishError!);
      _notify();
      return null;
    }

    final location = switch (locationMode) {
      TrackerLocationMode.gps => capturedLocation,
      TrackerLocationMode.manualZone =>
        manualZone.trim().isEmpty ? null : manualZone.trim(),
    };

    final payload = TrackerFinishPayload(
      startedAt: startedAt,
      endedAt: _now(),
      notes: notes,
      location: location,
      sets: payloadSets,
    );

    _finishState = const AsyncLoading();
    _notify();
    try {
      final session = await _repository.createWithPayload(
        payload.toCreateWorkoutPayload(),
      );
      savedSessionId = session.id;
      _finishState = AsyncData(session.id);
      pauseSessionTimer();
      pauseRestTimer();
      _notify();
      return session.id;
    } on SessionExpiredException {
      _sessionExpired = true;
      _finishState = const AsyncEmpty();
      _notify();
      return null;
    } catch (error, stackTrace) {
      finishError = error is AuthApiException
          ? error.message
          : 'No se pudo guardar la sesion';
      _finishState = AsyncError(error, stackTrace);
      _notify();
      return null;
    }
  }

  /// Referencia por posicion entre las series de este ejercicio en la sesion
  /// previa: el `order` del API es global y mezcla ejercicios.
  PreviousSetReference? _referenceForOrder(int position) {
    return findPreviousSetReferenceByPosition(
      sessions: _history,
      exerciseId: exerciseId,
      currentSessionId: 'active-tracker',
      currentStartedAt: startedAt,
      position: position,
    );
  }

  bool _validIndex(int index) => index >= 0 && index < _sets.length;

  static bool _isValidWeight(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return true;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null &&
        value.isFinite &&
        value >= 0 &&
        value <= maxWeightKg;
  }

  static bool _isValidReps(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return false;
    final value = int.tryParse(text);
    return value != null && value >= 1 && value <= maxReps;
  }

  static double? _parseWeight(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return '${value.toInt()}';
    return value.toStringAsFixed(1);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}

String formatTrackerDuration(Duration value) {
  final totalSeconds = value.inSeconds;
  final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
