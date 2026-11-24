import 'package:flutter/material.dart';

import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../domain/exercise_reference.dart';
import 'widgets/tracker_controls.dart';
import 'widgets/tracker_location_section.dart';
import 'widgets/tracker_sets_section.dart';
import 'widgets/tracker_timer_section.dart';

/// Datos visuales del ejercicio activo en el tracker.
class TrackerExerciseData {
  const TrackerExerciseData({
    required this.name,
    required this.tags,
    this.progressLabel,
    this.mediaCaption = 'Vista previa multimedia del ejercicio',
    this.media,
  });

  final String name;
  final List<String> tags;
  final String? progressLabel;
  final String mediaCaption;
  final Widget? media;
}

/// Datos de ejemplo para renderizar el tracker completo en modo preview UI.
class TrackerPreviewData {
  TrackerPreviewData._();

  static const exercise = TrackerExerciseData(
    name: 'Press de banca con barra',
    progressLabel: 'Ejercicio 1 de 4',
    tags: ['Pecho', 'Tríceps', 'Barra'],
  );

  static final List<TrackerSetItem> sets = [
    TrackerSetItem(
      id: 'preview-set-1',
      order: 1,
      weightText: '60',
      repsText: '10',
      completed: true,
      previousReference: PreviousSetReference(
        performedAt: DateTime(2026, 3, 28),
        weightKg: 60,
        reps: 10,
      ),
    ),
    TrackerSetItem(
      id: 'preview-set-2',
      order: 2,
      weightText: '65',
      repsText: '8',
      previousReference: PreviousSetReference(
        performedAt: DateTime(2026, 3, 28),
        weightKg: 62.5,
        reps: 8,
      ),
    ),
    const TrackerSetItem(
      id: 'preview-set-3',
      order: 3,
      weightText: '65',
      repsText: '8',
    ),
  ];
}

/// Pantalla de sesión activa del tracker de ejercicio (solo capa visual UI).
///
/// Expone callbacks y modelos inmutables para que la lógica de negocio
/// (ViewModel, cronómetros, API y ubicación) se conecte sin rehacer la vista.
class TrackerPage extends StatefulWidget {
  const TrackerPage({
    super.key,
    this.exercise,
    this.elapsedLabel = '00:24:18',
    this.isTimerRunning = true,
    this.restRemainingLabel = '01:30',
    this.isRestRunning = false,
    this.selectedRestSeconds = 90,
    this.restPresetSeconds = const [60, 90, 120],
    this.sets,
    this.notesController,
    this.initialNotes = '',
    this.locationMode = TrackerLocationMode.gps,
    this.gpsStatusLabel = 'Sin ubicación capturada todavía',
    this.manualZoneController,
    this.initialManualZone = '',
    this.finishLabel = 'Finalizar sesión',
    this.onBack,
    this.onChangeExercise,
    this.onPreviousExercise,
    this.onNextExercise,
    this.onOpenInstructions,
    this.onToggleTimer,
    this.onResetTimer,
    this.onToggleRestTimer,
    this.onResetRestTimer,
    this.onSelectRestPreset,
    this.onSetWeightChanged,
    this.onSetRepsChanged,
    this.onIncrementWeight,
    this.onDecrementWeight,
    this.onIncrementReps,
    this.onDecrementReps,
    this.onToggleSetCompleted,
    this.onRemoveSet,
    this.onAddSet,
    this.onNotesChanged,
    this.onLocationModeChanged,
    this.onRequestGps,
    this.onManualZoneChanged,
    this.onFinishSession,
  });

  final TrackerExerciseData? exercise;
  final String elapsedLabel;
  final bool isTimerRunning;
  final String restRemainingLabel;
  final bool isRestRunning;
  final int selectedRestSeconds;
  final List<int> restPresetSeconds;
  final List<TrackerSetItem>? sets;
  final TextEditingController? notesController;
  final String initialNotes;
  final TrackerLocationMode locationMode;
  final String gpsStatusLabel;
  final TextEditingController? manualZoneController;
  final String initialManualZone;
  final String finishLabel;

  final VoidCallback? onBack;
  final VoidCallback? onChangeExercise;

  /// Navegación entre ejercicios de una rutina; null oculta el botón.
  final VoidCallback? onPreviousExercise;
  final VoidCallback? onNextExercise;
  final VoidCallback? onOpenInstructions;
  final VoidCallback? onToggleTimer;
  final VoidCallback? onResetTimer;
  final VoidCallback? onToggleRestTimer;
  final VoidCallback? onResetRestTimer;
  final ValueChanged<int>? onSelectRestPreset;
  final void Function(int index, String value)? onSetWeightChanged;
  final void Function(int index, String value)? onSetRepsChanged;
  final ValueChanged<int>? onIncrementWeight;
  final ValueChanged<int>? onDecrementWeight;
  final ValueChanged<int>? onIncrementReps;
  final ValueChanged<int>? onDecrementReps;
  final ValueChanged<int>? onToggleSetCompleted;
  final ValueChanged<int>? onRemoveSet;
  final VoidCallback? onAddSet;
  final ValueChanged<String>? onNotesChanged;
  final ValueChanged<TrackerLocationMode>? onLocationModeChanged;
  final VoidCallback? onRequestGps;
  final ValueChanged<String>? onManualZoneChanged;
  final VoidCallback? onFinishSession;

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  TextEditingController? _ownedNotesController;
  TextEditingController? _ownedManualZoneController;
  late TrackerLocationMode _previewLocationMode;

  TextEditingController get _notesController =>
      widget.notesController ?? _ownedNotesController!;

  TextEditingController get _manualZoneController =>
      widget.manualZoneController ?? _ownedManualZoneController!;

  @override
  void initState() {
    super.initState();
    _previewLocationMode = widget.locationMode;
    if (widget.notesController == null) {
      _ownedNotesController = TextEditingController(text: widget.initialNotes);
    }
    if (widget.manualZoneController == null) {
      _ownedManualZoneController = TextEditingController(
        text: widget.initialManualZone,
      );
    }
  }

  @override
  void didUpdateWidget(covariant TrackerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locationMode != oldWidget.locationMode) {
      _previewLocationMode = widget.locationMode;
    }
    if (widget.notesController == null && _ownedNotesController == null) {
      _ownedNotesController = TextEditingController(text: widget.initialNotes);
    }
    if (widget.manualZoneController == null &&
        _ownedManualZoneController == null) {
      _ownedManualZoneController = TextEditingController(
        text: widget.initialManualZone,
      );
    }
  }

  @override
  void dispose() {
    _ownedNotesController?.dispose();
    _ownedManualZoneController?.dispose();
    super.dispose();
  }

  static void _noop() {}

  void _handleLocationModeChanged(TrackerLocationMode mode) {
    if (widget.onLocationModeChanged != null) {
      widget.onLocationModeChanged!(mode);
      return;
    }
    setState(() => _previewLocationMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise ?? TrackerPreviewData.exercise;
    final sets = widget.sets ?? TrackerPreviewData.sets;
    final activeLocationMode = widget.onLocationModeChanged != null
        ? widget.locationMode
        : _previewLocationMode;

    return AppScaffoldTemplate(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TrackerTopBar(
                  progressLabel: exercise.progressLabel,
                  onBack: widget.onBack ?? _noop,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    children: [
                      _ExerciseHeaderCard(
                        exercise: exercise,
                        onOpenInstructions: widget.onOpenInstructions ?? _noop,
                        onChangeExercise: widget.onChangeExercise,
                        onPreviousExercise: widget.onPreviousExercise,
                        onNextExercise: widget.onNextExercise,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TrackerTimerSection(
                        elapsedLabel: widget.elapsedLabel,
                        isTimerRunning: widget.isTimerRunning,
                        restRemainingLabel: widget.restRemainingLabel,
                        isRestRunning: widget.isRestRunning,
                        selectedRestSeconds: widget.selectedRestSeconds,
                        restPresetSeconds: widget.restPresetSeconds,
                        onToggleTimer: widget.onToggleTimer ?? _noop,
                        onResetTimer: widget.onResetTimer ?? _noop,
                        onToggleRestTimer: widget.onToggleRestTimer ?? _noop,
                        onResetRestTimer: widget.onResetRestTimer ?? _noop,
                        onSelectRestPreset: widget.onSelectRestPreset ?? (_) {},
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TrackerSetsSection(
                        sets: sets,
                        onWeightChanged: widget.onSetWeightChanged,
                        onRepsChanged: widget.onSetRepsChanged,
                        onIncrementWeight: widget.onIncrementWeight ?? (_) {},
                        onDecrementWeight: widget.onDecrementWeight ?? (_) {},
                        onIncrementReps: widget.onIncrementReps ?? (_) {},
                        onDecrementReps: widget.onDecrementReps ?? (_) {},
                        onToggleCompleted:
                            widget.onToggleSetCompleted ?? (_) {},
                        onRemoveSet: widget.onRemoveSet ?? (_) {},
                        onAddSet: widget.onAddSet ?? _noop,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _NotesSection(
                        controller: _notesController,
                        onChanged: widget.onNotesChanged,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TrackerLocationSection(
                        mode: activeLocationMode,
                        manualZoneController: _manualZoneController,
                        gpsStatusLabel: widget.gpsStatusLabel,
                        onModeChanged: _handleLocationModeChanged,
                        onRequestGps: widget.onRequestGps ?? _noop,
                        onManualZoneChanged: widget.onManualZoneChanged,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: widget.finishLabel,
                        onPressed: widget.onFinishSession ?? _noop,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackerTopBar extends StatelessWidget {
  const _TrackerTopBar({required this.onBack, this.progressLabel});

  final VoidCallback onBack;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          TrackerIconControl(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onPressed: onBack,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sesión activa',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (progressLabel != null)
                  Text(
                    progressLabel!,
                    style: AppTypography.body.copyWith(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const TrackerTagChip(label: 'Tracker', highlighted: true),
        ],
      ),
    );
  }
}

class _ExerciseHeaderCard extends StatelessWidget {
  const _ExerciseHeaderCard({
    required this.exercise,
    required this.onOpenInstructions,
    this.onChangeExercise,
    this.onPreviousExercise,
    this.onNextExercise,
  });

  final TrackerExerciseData exercise;
  final VoidCallback onOpenInstructions;
  final VoidCallback? onChangeExercise;
  final VoidCallback? onPreviousExercise;
  final VoidCallback? onNextExercise;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.inner),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  exercise.media ??
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF141824), Color(0xFF0A0C12)],
                      ),
                      border: Border.all(color: AppColors.glassBorder),
                      borderRadius: BorderRadius.circular(AppRadii.inner),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: AppColors.glassBorderStrong,
                              ),
                            ),
                            child: const Icon(
                              Icons.fitness_center_rounded,
                              color: AppColors.accentSilver,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            exercise.mediaCaption,
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            exercise.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
          if (exercise.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tag in exercise.tags) TrackerTagChip(label: tag),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TrackerGlassButton(
                label: 'Ver instrucciones',
                icon: Icons.menu_book_rounded,
                compact: true,
                onPressed: onOpenInstructions,
              ),
              if (onChangeExercise != null)
                TrackerGlassButton(
                  label: 'Cambiar ejercicio',
                  icon: Icons.swap_horiz_rounded,
                  compact: true,
                  onPressed: onChangeExercise,
                ),
            ],
          ),
          if (onPreviousExercise != null || onNextExercise != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TrackerGlassButton(
                    label: 'Anterior',
                    icon: Icons.chevron_left_rounded,
                    compact: true,
                    onPressed: onPreviousExercise,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TrackerGlassButton(
                    label: 'Siguiente ejercicio',
                    icon: Icons.chevron_right_rounded,
                    compact: true,
                    onPressed: onNextExercise,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas de la sesión',
            style: AppTypography.cta.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            onChanged: onChanged,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.5,
            ),
            cursorColor: AppColors.accentWhite,
            decoration: InputDecoration(
              hintText: 'Agrega sensaciones, técnica o ajustes para la próxima sesión...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: const Color(0xB807080C),
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.input),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.input),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
