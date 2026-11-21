import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../exercises/data/exercise.dart';
import '../../exercises/data/exercises_api.dart';
import '../data/geolocator_tracker_location_provider.dart';
import '../data/workouts_api.dart';
import '../data/workouts_repository_impl.dart';
import '../domain/tracker_location_provider.dart';
import '../domain/workouts_repository.dart';
import 'tracker_page.dart';
import 'tracker_view_model.dart';

/// Argumentos opcionales al abrir `/app/tracker`.
class TrackerSessionArgs {
  const TrackerSessionArgs({this.exercise});

  final Exercise? exercise;
}

/// Host que conecta [TrackerViewModel] con la UI del Agente UI.
class TrackerSessionPage extends StatefulWidget {
  const TrackerSessionPage({
    super.key,
    this.args,
    this.workoutsRepository,
    this.exercisesApi,
    this.locationProvider,
    this.apiClient,
  });

  final TrackerSessionArgs? args;
  final WorkoutsRepository? workoutsRepository;
  final ExercisesApi? exercisesApi;
  final TrackerLocationProvider? locationProvider;
  final ApiClient? apiClient;

  @override
  State<TrackerSessionPage> createState() => _TrackerSessionPageState();
}

class _TrackerSessionPageState extends State<TrackerSessionPage> {
  ApiClient? _ownedClient;
  TrackerViewModel? _viewModel;
  String? _bootstrapError;
  bool _bootstrapping = true;

  final _notesController = TextEditingController();
  final _manualZoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final client = widget.apiClient ?? (_ownedClient = ApiClient());
      final workouts =
          widget.workoutsRepository ??
          ApiWorkoutsRepository(WorkoutsApi(client));
      final exercise = widget.args?.exercise ?? await _resolveExercise(client);
      if (!mounted) return;
      if (exercise == null) {
        setState(() {
          _bootstrapping = false;
          _bootstrapError =
              'No hay ejercicios en el catalogo para iniciar el tracker.';
        });
        return;
      }

      final vm = TrackerViewModel(
        repository: workouts,
        exerciseId: exercise.id,
        exerciseName: exercise.nameEs?.isNotEmpty == true
            ? exercise.nameEs!
            : exercise.name,
        exerciseTags: [
          exercise.bodyPart,
          exercise.equipment,
          exercise.target,
        ].where((tag) => tag.trim().isNotEmpty).toList(),
        instructionsText: exercise.instructionsEs,
        locationProvider:
            widget.locationProvider ?? GeolocatorTrackerLocationProvider(),
      );
      vm.addListener(_onVm);
      setState(() {
        _viewModel = vm;
        _bootstrapping = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bootstrapping = false;
        _bootstrapError = 'No se pudo preparar la sesion del tracker.';
      });
    }
  }

  Future<Exercise?> _resolveExercise(ApiClient client) async {
    final api = widget.exercisesApi ?? ExercisesApi(client);
    final page = await api.fetchPage(page: 1, pageSize: 1);
    if (page.items.isEmpty) return null;
    return page.items.first;
  }

  void _onVm() {
    final vm = _viewModel;
    if (vm == null || !mounted) return;
    if (vm.sessionExpired) {
      context.go('/login');
      return;
    }
    if (_notesController.text != vm.notes) {
      _notesController.value = TextEditingValue(
        text: vm.notes,
        selection: TextSelection.collapsed(offset: vm.notes.length),
      );
    }
    if (_manualZoneController.text != vm.manualZone) {
      _manualZoneController.value = TextEditingValue(
        text: vm.manualZone,
        selection: TextSelection.collapsed(offset: vm.manualZone.length),
      );
    }
    setState(() {});
  }

  Future<void> _finish() async {
    final vm = _viewModel;
    if (vm == null) return;
    final id = await vm.finishSession();
    if (!mounted) return;
    if (id != null) {
      context.go('/app/entrenamientos/$id');
      return;
    }
    if (vm.finishError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(vm.finishError!)));
    }
  }

  void _openInstructions() {
    final text = _viewModel?.instructionsText?.trim();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1118),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          (text == null || text.isEmpty)
              ? 'Este ejercicio aun no tiene instrucciones en el catalogo.'
              : text,
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onVm);
    _viewModel?.dispose();
    _notesController.dispose();
    _manualZoneController.dispose();
    _ownedClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentWhite),
        ),
      );
    }

    if (_bootstrapError != null || _viewModel == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _bootstrapError ?? 'Tracker no disponible',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.dangerText),
            ),
          ),
        ),
      );
    }

    final vm = _viewModel!;
    final finishing = vm.finishState.isLoading;

    return TrackerPage(
      exercise: vm.exerciseData,
      elapsedLabel: vm.elapsedLabel,
      isTimerRunning: vm.isSessionTimerRunning,
      restRemainingLabel: vm.restRemainingLabel,
      isRestRunning: vm.isRestRunning,
      selectedRestSeconds: vm.selectedRestSeconds,
      restPresetSeconds: vm.restPresetSeconds,
      sets: vm.setItems,
      notesController: _notesController,
      locationMode: vm.locationMode,
      gpsStatusLabel: vm.gpsStatusLabel,
      manualZoneController: _manualZoneController,
      finishLabel: finishing ? 'Guardando...' : 'Finalizar sesión',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/app');
        }
      },
      onOpenInstructions: _openInstructions,
      onToggleTimer: vm.toggleSessionTimer,
      onResetTimer: vm.resetSessionTimer,
      onToggleRestTimer: vm.toggleRestTimer,
      onResetRestTimer: vm.resetRestTimer,
      onSelectRestPreset: vm.selectRestPreset,
      onSetWeightChanged: vm.setWeightText,
      onSetRepsChanged: vm.setRepsText,
      onIncrementWeight: vm.incrementWeight,
      onDecrementWeight: vm.decrementWeight,
      onIncrementReps: vm.incrementReps,
      onDecrementReps: vm.decrementReps,
      onToggleSetCompleted: vm.toggleSetCompleted,
      onRemoveSet: vm.removeSet,
      onAddSet: vm.addSet,
      onNotesChanged: vm.updateNotes,
      onLocationModeChanged: vm.setLocationMode,
      onRequestGps: vm.requestGpsLocation,
      onManualZoneChanged: vm.updateManualZone,
      onFinishSession: finishing ? null : _finish,
    );
  }
}
