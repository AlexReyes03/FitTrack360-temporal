import 'package:flutter/foundation.dart';

import '../../workouts/domain/workout_session_draft.dart';
import '../domain/routine.dart';
import '../domain/start_session_from_routine.dart';

/// ViewModel de la acción «Iniciar sesión» desde una rutina.
class StartSessionViewModel extends ChangeNotifier {
  final StartSessionFromRoutine _useCase;

  StartSessionViewModel({StartSessionFromRoutine? useCase})
    : _useCase = useCase ?? StartSessionFromRoutine();

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Devuelve el borrador o `null` si la rutina no puede iniciar sesión.
  WorkoutSessionDraft? start(Routine routine) {
    try {
      final draft = _useCase(routine);
      _setError(null);
      return draft;
    } on EmptyRoutineException catch (error) {
      _setError(error.message);
      return null;
    }
  }

  void _setError(String? value) {
    if (_errorMessage == value) return;
    _errorMessage = value;
    notifyListeners();
  }
}
