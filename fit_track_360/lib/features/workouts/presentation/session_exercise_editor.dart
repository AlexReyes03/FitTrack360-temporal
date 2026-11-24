import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../exercises/data/exercises_api.dart';
import 'session_editor_view_model.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/tracker_controls.dart';
import 'widgets/workout_number_field.dart';

/// Editor glass de ejercicios y series para registrar o editar una sesión.
///
/// Es solo vista: el estado y la validación viven en
/// [SessionEditorViewModel]. Cada campo muestra su propio error.
class SessionExerciseEditor extends StatefulWidget {
  const SessionExerciseEditor({super.key, required this.viewModel, this.api});

  final SessionEditorViewModel viewModel;
  final ExercisesApi? api;

  @override
  State<SessionExerciseEditor> createState() => _SessionExerciseEditorState();
}

class _SessionExerciseEditorState extends State<SessionExerciseEditor> {
  ApiClient? _client;
  late final ExercisesApi _api =
      widget.api ?? ExercisesApi(_client = ApiClient());

  SessionEditorViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final exercise = await showExercisePickerSheet(context, api: _api);
    if (!mounted || exercise == null) return;
    _vm.addExercise(
      exerciseId: exercise.id,
      name: exercise.nameEs ?? exercise.name,
    );
  }

  void _removeExercise(int index) {
    final removed = _vm.removeExercise(index);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Quitaste ${removed.block.name}'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => _vm.restoreExercise(removed),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final blocks = _vm.blocks;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Agrega los ejercicios que hiciste.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            for (var b = 0; b < blocks.length; b++) ...[
              _BlockCard(
                key: ObjectKey(blocks[b]),
                viewModel: _vm,
                blockIndex: b,
                onRemove: () => _removeExercise(b),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            TrackerGlassButton(
              label: 'Agregar ejercicio',
              icon: Icons.add_rounded,
              onPressed: _addExercise,
            ),
          ],
        );
      },
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    super.key,
    required this.viewModel,
    required this.blockIndex,
    required this.onRemove,
  });

  final SessionEditorViewModel viewModel;
  final int blockIndex;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final block = viewModel.blocks[blockIndex];
    final reps = block.sets.first.repsText;
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.sm),
      radius: AppRadii.inner,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${block.sets.length} series × $reps reps',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              TrackerIconControl(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Quitar ejercicio',
                destructive: true,
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var s = 0; s < block.sets.length; s++) ...[
            _SetRow(
              key: ValueKey(block.sets[s].id),
              viewModel: viewModel,
              blockIndex: blockIndex,
              setIndex: s,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          TrackerGlassButton(
            label: 'Agregar serie',
            icon: Icons.add_rounded,
            compact: true,
            onPressed: () => viewModel.addSet(blockIndex),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.viewModel,
    required this.blockIndex,
    required this.setIndex,
  });

  final SessionEditorViewModel viewModel;
  final int blockIndex;
  final int setIndex;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  EditableSessionSet get _set =>
      widget.viewModel.blocks[widget.blockIndex].sets[widget.setIndex];

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: _set.repsText);
    _weight = TextEditingController(text: _set.weightText);
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_reps, _set.repsText);
    _sync(_weight, _set.weightText);
  }

  static void _sync(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final b = widget.blockIndex;
    final s = widget.setIndex;
    final canRemove = vm.blocks[b].sets.length > 1;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TrackerTagChip(label: 'Serie ${s + 1}'),
              const Spacer(),
              TrackerIconControl(
                icon: Icons.remove_circle_outline_rounded,
                tooltip: 'Quitar serie',
                size: 32,
                onPressed: canRemove ? () => vm.removeSet(b, s) : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: WorkoutStepperField(
                  label: 'Repeticiones',
                  fieldKey: Key('reps-$b-$s'),
                  controller: _reps,
                  inputFormatters: WorkoutInputFormatters.integer,
                  errorText: vm.repsError(b, s),
                  decrementTooltip: 'Disminuir repeticiones',
                  incrementTooltip: 'Aumentar repeticiones',
                  onChanged: (value) => vm.setReps(b, s, value),
                  onDecrement: () => vm.decrementReps(b, s),
                  onIncrement: () => vm.incrementReps(b, s),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: WorkoutStepperField(
                  label: 'Peso (kg)',
                  fieldKey: Key('weight-$b-$s'),
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: WorkoutInputFormatters.decimal,
                  errorText: vm.weightError(b, s),
                  decrementTooltip: 'Disminuir peso',
                  incrementTooltip: 'Aumentar peso',
                  onChanged: (value) => vm.setWeight(b, s, value),
                  onDecrement: () => vm.decrementWeight(b, s),
                  onIncrement: () => vm.incrementWeight(b, s),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
