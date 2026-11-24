import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../../exercises/data/exercise.dart';
import '../../exercises/data/exercise_labels.dart';
import '../domain/exercise_reference.dart';
import '../domain/tracker_finish_payload.dart';
import '../domain/tracker_location_provider.dart';
import '../domain/workout_session_draft.dart';
import '../domain/workouts_repository.dart';
import 'tracker_page.dart';
import 'widgets/tracker_location_section.dart';
import 'widgets/tracker_sets_section.dart';

/// Estado editable de una serie en la sesión activa.
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

/// Serie precargada de un ejercicio del plan (rutina o sesión repetida).
class TrackerPlannedSet {
  const TrackerPlannedSet({this.weightText = '', this.repsText = ''});

  final String weightText;
  final String repsText;
}

/// Ejercicio que se entrenará en el tracker, con sus series precargadas.
class TrackerExercisePlan {
  const TrackerExercisePlan({
    required this.exerciseId,
    required this.name,
    this.tags = const [],
    this.instructionsText,
    this.exercise,
    this.sets = const [],
  });

  /// Plan de un ejercicio del catálogo con etiquetas ya traducidas.
  factory TrackerExercisePlan.fromExercise(
    Exercise exercise, {
    List<TrackerPlannedSet> sets = const [],
  }) => TrackerExercisePlan(
    exerciseId: exercise.id,
    name: trackerExerciseName(exercise),
    tags: trackerExerciseTags(exercise),
    instructionsText: exercise.instructionsEs,
    exercise: exercise,
    sets: sets,
  );

  final String exerciseId;
  final String name;
  final List<String> tags;
  final String? instructionsText;

  /// Datos del catálogo (imagen, etiquetas); null mientras no se cargan.
  final Exercise? exercise;
  final List<TrackerPlannedSet> sets;

  /// Convierte el borrador de una rutina o de una sesión repetida en el plan
  /// del tracker: series exactas si las trae, si no `targetSets × targetReps`.
  static List<TrackerExercisePlan> listFromDraft(WorkoutSessionDraft draft) {
    final ordered = [...draft.exercises]
      ..sort((a, b) => a.position.compareTo(b.position));
    return [
      for (final exercise in ordered)
        TrackerExercisePlan(
          exerciseId: exercise.exerciseId,
          name: exercise.exerciseName.trim().isEmpty
              ? 'Ejercicio ${exercise.exerciseId}'
              : exercise.exerciseName,
          sets: _plannedSets(draft, exercise),
        ),
    ];
  }

  static List<TrackerPlannedSet> _plannedSets(
    WorkoutSessionDraft draft,
    PlannedExercise exercise,
  ) {
    final exact = draft.sets
        ?.where((set) => set.exerciseId == exercise.exerciseId)
        .toList();
    if (exact != null && exact.isNotEmpty) {
      return [
        for (final set in exact)
          TrackerPlannedSet(
            weightText: set.weightKg <= 0
                ? ''
                : TrackerViewModel.formatNumber(set.weightKg),
            repsText: '${set.reps}',
          ),
      ];
    }
    return [
      for (var i = 0; i < exercise.targetSets; i++)
        TrackerPlannedSet(repsText: '${exercise.targetReps}'),
    ];
  }
}

/// Nombre visible del ejercicio: `nameEs` si existe.
String trackerExerciseName(Exercise exercise) =>
    exercise.nameEs?.trim().isNotEmpty == true
    ? exercise.nameEs!.trim()
    : exercise.name;

/// Etiquetas traducidas, igual que en el catálogo (sin repetir).
List<String> trackerExerciseTags(Exercise exercise) {
  final tags = <String>[];
  void add(String raw, String Function(String) translate) {
    if (raw.trim().isEmpty) return;
    final label = translate(raw.trim());
    if (!tags.contains(label)) tags.add(label);
  }

  add(exercise.bodyPart, translateBodyPart);
  add(exercise.target, translateTarget);
  add(exercise.equipment, translateEquipment);
  return tags;
}

class _TrackerSlot {
  _TrackerSlot(this.plan, this.sets);

  TrackerExercisePlan plan;
  List<TrackerEditableSet> sets;
}

/// ViewModel del tracker live: timers locales, series, P2 y persistencia.
class TrackerViewModel extends ChangeNotifier {
  /// Tracker de un solo ejercicio.
  TrackerViewModel({
    required WorkoutsRepository repository,
    required TrackerLocationProvider locationProvider,
    required String exerciseId,
    required String exerciseName,
    List<String> exerciseTags = const [],
    String? instructionsText,
    DateTime Function()? now,
    int initialSetCount = 3,
    List<int> restPresetSeconds = const [60, 90, 120],
    bool autoStartSessionTimer = true,
  }) : this.plan(
         repository: repository,
         locationProvider: locationProvider,
         exercises: [
           TrackerExercisePlan(
             exerciseId: exerciseId,
             name: exerciseName,
             tags: exerciseTags,
             instructionsText: instructionsText,
           ),
         ],
         now: now,
         initialSetCount: initialSetCount,
         restPresetSeconds: restPresetSeconds,
         autoStartSessionTimer: autoStartSessionTimer,
       );

  /// Tracker de varios ejercicios (rutina o sesión repetida).
  TrackerViewModel.plan({
    required this._repository,
    required this._locationProvider,
    required List<TrackerExercisePlan> exercises,
    this.routineId,
    DateTime Function()? now,
    this.initialSetCount = 3,
    this.restPresetSeconds = const [60, 90, 120],
    this.autoStartSessionTimer = true,
  }) : assert(exercises.isNotEmpty),
       _now = now ?? DateTime.now,
       startedAt = (now ?? DateTime.now)(),
       selectedRestSeconds = 90,
       restRemaining = const Duration(seconds: 90) {
    _slots = [for (final plan in exercises) _newSlot(plan)];
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

  /// Rutina de origen; se envía al finalizar.
  final String? routineId;
  final int initialSetCount;
  final List<int> restPresetSeconds;
  final bool autoStartSessionTimer;

  late List<_TrackerSlot> _slots;
  int _current = 0;

  final DateTime startedAt;

  Timer? _sessionTimer;
  Timer? _restTimer;

  Duration _elapsed = Duration.zero;
  bool _sessionRunning = false;

  Duration restRemaining;
  bool _restRunning = false;
  int selectedRestSeconds;

  String notes = '';
  TrackerLocationMode locationMode = TrackerLocationMode.gps;
  String manualZone = '';
  String gpsStatusLabel = 'Sin ubicación capturada todavía';
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

  List<TrackerEditableSet> get _sets => _slots[_current].sets;
  set _sets(List<TrackerEditableSet> value) => _slots[_current].sets = value;

  TrackerExercisePlan get _plan => _slots[_current].plan;
  String get exerciseId => _plan.exerciseId;
  String get exerciseName => _plan.name;
  List<String> get exerciseTags => _plan.tags;
  String? get instructionsText => _plan.instructionsText;

  /// Ejercicio del catálogo activo (imagen y etiquetas), si ya se conoce.
  Exercise? get currentExercise => _plan.exercise;
  int get exerciseCount => _slots.length;
  int get currentExerciseIndex => _current;
  bool get hasPreviousExercise => _current > 0;
  bool get hasNextExercise => _current < _slots.length - 1;

  /// Ids del plan que aún no tienen datos del catálogo (imagen, etiquetas).
  Set<String> get exerciseIdsWithoutDetails => {
    for (final slot in _slots)
      if (slot.plan.exercise == null) slot.plan.exerciseId,
  };

  TrackerExerciseData get exerciseData => TrackerExerciseData(
    name: exerciseName,
    tags: exerciseTags,
    progressLabel: _slots.length > 1
        ? 'Ejercicio ${_current + 1} de ${_slots.length}'
        : 'Sesión en curso',
  );

  void nextExercise() {
    if (!hasNextExercise) return;
    _current++;
    _notify();
  }

  void previousExercise() {
    if (!hasPreviousExercise) return;
    _current--;
    _notify();
  }

  /// Cambia el ejercicio activo por otro del catálogo con series nuevas.
  void replaceCurrentExercise(TrackerExercisePlan plan) {
    _slots[_current] = _newSlot(plan);
    _notify();
  }

  /// Completa los datos del catálogo (imagen, etiquetas, instrucciones) de
  /// un ejercicio del plan cargado solo por id.
  void attachExerciseDetails(String exerciseId, Exercise exercise) {
    var changed = false;
    for (final slot in _slots) {
      if (slot.plan.exerciseId != exerciseId || slot.plan.exercise != null) {
        continue;
      }
      final named = slot.plan.name.startsWith('Ejercicio ')
          ? trackerExerciseName(exercise)
          : slot.plan.name;
      slot.plan = TrackerExercisePlan(
        exerciseId: exerciseId,
        name: named,
        tags: trackerExerciseTags(exercise),
        instructionsText: exercise.instructionsEs,
        exercise: exercise,
        sets: slot.plan.sets,
      );
      changed = true;
    }
    if (changed) _notify();
  }

  _TrackerSlot _newSlot(TrackerExercisePlan plan) {
    final planned = plan.sets;
    final count = planned.isEmpty ? initialSetCount : planned.length;
    final sets = [
      for (var i = 0; i < count; i++)
        TrackerEditableSet(
          id: 'set-${plan.exerciseId}-${_nextSetId++}',
          order: i + 1,
          weightText: planned.isEmpty ? '' : planned[i].weightText,
          repsText: planned.isEmpty ? '' : planned[i].repsText,
          previousReference: _referenceFor(plan.exerciseId, i + 1),
        ),
    ];
    return _TrackerSlot(plan, sets);
  }

  int _nextSetId = 0;

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

  /// Avanza un segundo del cronómetro (también usable en pruebas).
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

  /// Avanza un segundo del descanso (también usable en pruebas).
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
        id: 'set-$exerciseId-${_nextSetId++}',
        order: order,
        previousReference: _referenceFor(exerciseId, order),
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
      next[i].previousReference = _referenceFor(exerciseId, i + 1);
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
    setWeightText(index, formatNumber(current + 2.5));
  }

  void decrementWeight(int index) {
    if (!_validIndex(index)) return;
    final current = _parseWeight(_sets[index].weightText) ?? 0;
    final next = current - 2.5;
    setWeightText(index, next <= 0 ? '' : formatNumber(next));
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
    gpsStatusLabel = 'Obteniendo ubicación aproximada...';
    _notify();
    final fix = await _locationProvider.getApproximateLocation();
    if (fix == null) {
      gpsStatusLabel =
          'No se pudo obtener GPS. Usa zona manual o continúa sin ubicación.';
      locationMode = TrackerLocationMode.manualZone;
      capturedLocation = manualZone.trim().isEmpty ? null : manualZone.trim();
      _notify();
      return;
    }
    capturedLocation = fix.label;
    gpsStatusLabel = 'Ubicación aproximada: ${fix.label}';
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
      for (final slot in _slots) {
        for (final set in slot.sets) {
          set.previousReference = _referenceFor(
            slot.plan.exerciseId,
            set.order,
          );
        }
      }
      _notify();
    } on SessionExpiredException {
      _sessionExpired = true;
      _notify();
    } catch (_) {
      // Sin historial no bloquea el tracker.
    }
  }

  /// Valida las series completadas de todos los ejercicios y persiste la
  /// sesión. Devuelve el id creado o null. Las series pendientes no se
  /// validan ni se envían.
  Future<String?> finishSession() async {
    finishError = null;
    final payloadSets = <TrackerFinishSet>[];
    var completedCount = 0;
    int? firstSlotWithError;

    for (var slotIndex = 0; slotIndex < _slots.length; slotIndex++) {
      final slot = _slots[slotIndex];
      for (final set in slot.sets) {
        if (!set.completed) continue;
        completedCount++;
        final weightOk = _isValidWeight(set.weightText);
        final repsOk = _isValidReps(set.repsText);
        set.hasWeightError = !weightOk;
        set.hasRepsError = !repsOk;
        if (!weightOk || !repsOk) {
          firstSlotWithError ??= slotIndex;
          continue;
        }
        payloadSets.add(
          TrackerFinishSet(
            exerciseId: slot.plan.exerciseId,
            order: payloadSets.length + 1,
            weightKg: _parseWeight(set.weightText) ?? 0,
            reps: int.parse(set.repsText.trim()),
          ),
        );
      }
    }

    if (completedCount == 0 || firstSlotWithError != null) {
      finishError = completedCount == 0
          ? 'Completa al menos una serie'
          : 'Corrige peso y repeticiones de las series completadas';
      if (firstSlotWithError != null) _current = firstSlotWithError;
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
      routineId: routineId,
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
          : 'No se pudo guardar la sesión';
      _finishState = AsyncError(error, stackTrace);
      _notify();
      return null;
    }
  }

  /// Referencia por posición entre las series de este ejercicio en la sesión
  /// previa: el `order` del API es global y mezcla ejercicios.
  PreviousSetReference? _referenceFor(String exerciseId, int position) {
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

  static String formatNumber(double value) {
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
