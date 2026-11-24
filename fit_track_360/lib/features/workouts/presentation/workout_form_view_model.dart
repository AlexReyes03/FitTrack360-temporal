import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../data/workout_session.dart';
import '../data/workouts_api.dart';
import '../domain/workout_session_draft.dart';
import 'session_editor_view_model.dart';

/// Resultado de guardar el formulario.
enum WorkoutFormSaveResult { saved, invalid, failed, sessionExpired }

/// ViewModel de «Registrar entrenamiento pasado» y «Editar sesión».
///
/// Un registro pasado siempre se guarda finalizado: `endedAt` es el inicio más
/// la duración capturada. Así no queda «En curso» ni aparece como sesión
/// activa en Inicio.
class WorkoutFormViewModel extends ChangeNotifier {
  WorkoutFormViewModel({
    required this._api,
    this.editingSession,
    WorkoutSessionDraft? draft,
    DateTime Function()? now,
  }) : _draft = draft {
    final clock = now ?? DateTime.now;
    final session = editingSession;
    _startedAt =
        session?.startedAt.toLocal() ?? draft?.startedAt.toLocal() ?? clock();
    final ended = session?.endedAt ?? draft?.endedAt;
    if (session != null || draft?.endedAt != null) {
      final minutes = ended?.difference(session?.startedAt ?? draft!.startedAt);
      _durationText = minutes == null || minutes.inMinutes <= 0
          ? ''
          : '${minutes.inMinutes}';
    }
    _notes = session?.notes ?? draft?.notes ?? '';
    editor = SessionEditorViewModel(
      initial: session != null ? draftFromSession(session) : draft,
    )..addListener(_notify);
  }

  static const int defaultDurationMinutes = 60;
  static const int maxDurationMinutes = 600;
  static const int defaultRestSeconds = 90;
  static const int maxRestSeconds = 900;

  final WorkoutsApi _api;
  final WorkoutSession? editingSession;
  final WorkoutSessionDraft? _draft;
  late final SessionEditorViewModel editor;

  late DateTime _startedAt;
  String _durationText = '$defaultDurationMinutes';
  String _restText = '$defaultRestSeconds';
  String _notes = '';
  bool _restEdited = false;
  bool _durationTouched = false;
  bool _restTouched = false;
  bool _submitted = false;
  bool _formDirty = false;
  bool _saving = false;
  String? _saveError;
  bool _disposed = false;

  bool get isEditing => editingSession != null;
  String? get routineName => _draft?.routineName;
  DateTime get startedAt => _startedAt;
  String get durationText => _durationText;
  String get restText => _restText;
  String get notes => _notes;
  bool get saving => _saving;
  String? get saveError => _saveError;

  /// Hay cambios sin guardar (para «¿Descartar cambios?»).
  bool get dirty => _formDirty || editor.dirty;

  String? get durationError {
    if (!_submitted && !_durationTouched) return null;
    final text = _durationText.trim();
    if (text.isEmpty) return 'Indica cuánto duró el entrenamiento';
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > maxDurationMinutes) {
      return 'De 1 a $maxDurationMinutes minutos';
    }
    return null;
  }

  String? get restError {
    if (!_submitted && !_restTouched) return null;
    final value = int.tryParse(_restText.trim());
    if (value == null || value > maxRestSeconds) {
      return 'De 0 a $maxRestSeconds segundos';
    }
    return null;
  }

  void setStartedAt(DateTime value) {
    _startedAt = value;
    _formDirty = true;
    _notify();
  }

  void setDuration(String value) {
    _durationText = value;
    _durationTouched = true;
    _formDirty = true;
    _notify();
  }

  void setRest(String value) {
    _restText = value;
    _restEdited = true;
    _restTouched = true;
    _formDirty = true;
    _notify();
  }

  void setNotes(String value) {
    _notes = value;
    _formDirty = true;
    _notify();
  }

  /// Aplica el descanso preferido del perfil solo si la persona no lo editó.
  void applyProfileRest(int seconds) {
    if (_restEdited) return;
    _restText = '$seconds';
    _notify();
  }

  Future<WorkoutFormSaveResult> save() async {
    if (_saving) return WorkoutFormSaveResult.invalid;
    _submitted = true;
    editor.revealErrors();
    if (durationError != null || restError != null || !editor.isValid) {
      _notify();
      return WorkoutFormSaveResult.invalid;
    }
    _saving = true;
    _saveError = null;
    _notify();
    final endedAt = _startedAt.add(
      Duration(minutes: int.parse(_durationText.trim())),
    );
    final base =
        _draft ?? WorkoutSessionDraft(startedAt: _startedAt, exercises: []);
    final draft = base.edited(
      startedAt: _startedAt,
      endedAt: endedAt,
      notes: _notes,
      exercises: editor.exercises,
      sets: editor.sets,
    );
    try {
      if (editingSession case final session?) {
        final payload = draft.toCreateWorkoutPayload()..remove('routineId');
        payload['notes'] = _notes.trim();
        payload['sets'] ??= <Object>[];
        await _api.update(session.id, payload);
      } else {
        await _api.create(draft);
      }
      _formDirty = false;
      return WorkoutFormSaveResult.saved;
    } on SessionExpiredException {
      return WorkoutFormSaveResult.sessionExpired;
    } catch (error) {
      _saveError = error is AuthApiException
          ? error.message
          : 'No se pudo conectar';
      return WorkoutFormSaveResult.failed;
    } finally {
      _saving = false;
      _notify();
    }
  }

  /// Borrador equivalente a una sesión guardada, para editarla.
  static WorkoutSessionDraft draftFromSession(WorkoutSession session) {
    final groups = <String, List<int>>{};
    final named = <String, String>{};
    for (final set in session.sets) {
      final id = set.exerciseId;
      if (id == null) continue;
      groups.putIfAbsent(id, () => []).add(set.reps);
      named.putIfAbsent(id, () => set.exerciseName);
    }
    var position = 0;
    var order = 0;
    return WorkoutSessionDraft(
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      notes: session.notes,
      exercises: [
        for (final entry in groups.entries)
          PlannedExercise(
            exerciseId: entry.key,
            exerciseName: named[entry.key]!,
            position: position++,
            targetSets: entry.value.length,
            targetReps: entry.value.first,
          ),
      ],
      sets: [
        for (final set in session.sets)
          if (set.exerciseId != null)
            PlannedSet(
              exerciseId: set.exerciseId!,
              order: set.order ?? ++order,
              weightKg: set.weightKg ?? 0,
              reps: set.reps,
            ),
      ],
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    editor
      ..removeListener(_notify)
      ..dispose();
    super.dispose();
  }
}
