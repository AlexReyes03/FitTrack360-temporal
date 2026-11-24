import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../exercises/data/exercise.dart';
import '../../exercises/data/exercises_api.dart';
import '../../exercises/presentation/widgets/exercise_media_view.dart';
import '../data/geolocator_tracker_location_provider.dart';
import '../data/workouts_api.dart';
import '../data/workouts_repository_impl.dart';
import '../domain/tracker_location_provider.dart';
import '../domain/workout_session_draft.dart';
import '../domain/workouts_repository.dart';
import 'tracker_page.dart';
import 'tracker_view_model.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/tracker_controls.dart';
import 'widgets/workout_dialogs.dart';

/// Ruta del tracker («Entrenar ahora»). Igual a `appTrackerPath` del router.
const workoutTrackerRoute = '/app/tracker';

/// Argumentos opcionales al abrir `/app/tracker`.
///
/// [draft] viene de una rutina o de «Repetir»; [exercise], de un ejercicio
/// del catálogo. Sin ninguno, el tracker pide elegir un ejercicio.
class TrackerSessionArgs {
  const TrackerSessionArgs({this.exercise, this.draft});

  final Exercise? exercise;
  final WorkoutSessionDraft? draft;
}

/// Host que conecta [TrackerViewModel] con la UI del tracker.
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
  bool _leaving = false;

  final _notesController = TextEditingController();
  final _manualZoneController = TextEditingController();

  ApiClient get _client => widget.apiClient ?? (_ownedClient ??= ApiClient());

  late final ExercisesApi _exercisesApi =
      widget.exercisesApi ?? ExercisesApi(_client);

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args?.draft case final draft? when draft.exercises.isNotEmpty) {
      _start(
        TrackerExercisePlan.listFromDraft(draft),
        routineId: draft.routineId,
        notes: draft.notes,
      );
    } else if (args?.exercise case final exercise?) {
      _start([TrackerExercisePlan.fromExercise(exercise)]);
    }
  }

  void _start(
    List<TrackerExercisePlan> plans, {
    String? routineId,
    String? notes,
  }) {
    final vm = TrackerViewModel.plan(
      repository:
          widget.workoutsRepository ??
          ApiWorkoutsRepository(WorkoutsApi(_client)),
      locationProvider:
          widget.locationProvider ?? GeolocatorTrackerLocationProvider(),
      exercises: plans,
      routineId: routineId,
    );
    final trimmed = notes?.trim();
    if (trimmed != null && trimmed.isNotEmpty) vm.updateNotes(trimmed);
    vm.addListener(_onVm);
    _viewModel = vm;
    _notesController.text = vm.notes;
    _loadExerciseDetails(vm);
  }

  /// Los ejercicios de una rutina llegan solo con id y nombre: se completa
  /// la imagen y las etiquetas desde el catálogo, sin bloquear el tracker.
  Future<void> _loadExerciseDetails(TrackerViewModel vm) async {
    for (final id in vm.exerciseIdsWithoutDetails) {
      try {
        final exercise = await _exercisesApi.fetchById(id);
        if (!mounted || _viewModel != vm) return;
        vm.attachExerciseDetails(id, exercise);
      } on SessionExpiredException {
        if (mounted) context.go('/login');
        return;
      } catch (_) {
        // Sin detalle se muestra el nombre y el marcador de imagen.
      }
    }
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

  Future<void> _pickExercise() async {
    final exercise = await showExercisePickerSheet(context, api: _exercisesApi);
    if (exercise == null || !mounted) return;
    final plan = TrackerExercisePlan.fromExercise(exercise);
    final vm = _viewModel;
    if (vm == null) {
      setState(() => _start([plan]));
    } else {
      vm.replaceCurrentExercise(plan);
    }
  }

  Future<void> _finish() async {
    final vm = _viewModel;
    if (vm == null) return;
    final id = await vm.finishSession();
    if (!mounted) return;
    if (id != null) {
      _leaving = true;
      context.go('/app/entrenamientos/$id');
      return;
    }
    if (vm.finishError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(vm.finishError!)));
    }
  }

  /// Salir con una sesión activa pide confirmación (botón y gesto del
  /// sistema); sin sesión sale directo.
  Future<void> _requestExit() async {
    if (_viewModel != null && !_leaving) {
      final discard = await showDiscardSessionDialog(context);
      if (!discard || !mounted) return;
    }
    setState(() => _leaving = true);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app');
    }
  }

  void _openInstructions() {
    final text = _viewModel?.instructionsText?.trim();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: GlassSurface(
          child: Text(
            (text == null || text.isEmpty)
                ? 'Este ejercicio aún no tiene instrucciones en el catálogo.'
                : text,
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
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
    return PopScope<Object?>(
      canPop: _leaving || _viewModel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: _viewModel == null ? _chooseExercise() : _tracker(_viewModel!),
    );
  }

  Widget _chooseExercise() {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              children: [
                TrackerIconControl(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Volver',
                  onPressed: _requestExit,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Entrenar ahora',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.accentSilver,
                    size: 32,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Elige un ejercicio para empezar',
                    textAlign: TextAlign.center,
                    style: AppTypography.cta.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'El cronómetro arranca cuando lo eliges. También puedes '
                    'entrenar una de tus rutinas.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Elegir ejercicio',
                    onPressed: _pickExercise,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TrackerGlassButton(
                    label: 'Ver rutinas',
                    icon: Icons.list_alt_rounded,
                    onPressed: () => context.push('/app/rutinas'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tracker(TrackerViewModel vm) {
    final finishing = vm.finishState.isLoading;
    final data = vm.exerciseData;
    final exercise = vm.currentExercise;
    final multiple = vm.exerciseCount > 1;

    return TrackerPage(
      exercise: TrackerExerciseData(
        name: data.name,
        tags: data.tags,
        progressLabel: data.progressLabel,
        media: exercise == null
            ? null
            : ExerciseMediaView(
                key: ValueKey('tracker-media-${exercise.id}'),
                exercise: exercise,
                animate: true,
              ),
      ),
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
      onBack: _requestExit,
      onChangeExercise: _pickExercise,
      onPreviousExercise: multiple && vm.hasPreviousExercise
          ? vm.previousExercise
          : null,
      onNextExercise: multiple && vm.hasNextExercise ? vm.nextExercise : null,
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
