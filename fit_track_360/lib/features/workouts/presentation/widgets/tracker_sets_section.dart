import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../domain/exercise_reference.dart';
import 'previous_set_reference.dart';
import 'tracker_controls.dart';
import 'workout_number_field.dart';

/// Modelo visual de una fila de serie en el tracker.
class TrackerSetItem {
  const TrackerSetItem({
    required this.id,
    required this.order,
    required this.weightText,
    required this.repsText,
    this.completed = false,
    this.previousReference,
    this.hasWeightError = false,
    this.hasRepsError = false,
    this.errorText,
  });

  final String id;
  final int order;
  final String weightText;
  final String repsText;
  final bool completed;
  final PreviousSetReference? previousReference;
  final bool hasWeightError;
  final bool hasRepsError;

  /// Mensaje visible bajo la serie cuando peso o repeticiones son invalidos.
  final String? errorText;
}

/// Bloque editable visual de series (peso, reps, estado, +/- y agregar/quitar).
class TrackerSetsSection extends StatelessWidget {
  const TrackerSetsSection({
    super.key,
    required this.sets,
    this.onWeightChanged,
    this.onRepsChanged,
    this.onIncrementWeight,
    this.onDecrementWeight,
    this.onIncrementReps,
    this.onDecrementReps,
    this.onToggleCompleted,
    this.onRemoveSet,
    this.onAddSet,
  });

  final List<TrackerSetItem> sets;
  final void Function(int index, String value)? onWeightChanged;
  final void Function(int index, String value)? onRepsChanged;
  final ValueChanged<int>? onIncrementWeight;
  final ValueChanged<int>? onDecrementWeight;
  final ValueChanged<int>? onIncrementReps;
  final ValueChanged<int>? onDecrementReps;
  final ValueChanged<int>? onToggleCompleted;
  final ValueChanged<int>? onRemoveSet;
  final VoidCallback? onAddSet;

  @override
  Widget build(BuildContext context) {
    final completedCount = sets.where((set) => set.completed).length;

    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Series',
                  style: AppTypography.cta.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TrackerTagChip(
                label: '$completedCount/${sets.length} completadas',
                highlighted: sets.isNotEmpty && completedCount == sets.length,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (sets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Aún no hay series registradas para este ejercicio.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (var index = 0; index < sets.length; index++) ...[
              _TrackerSetRow(
                key: ValueKey(sets[index].id),
                item: sets[index],
                onWeightChanged: onWeightChanged == null
                    ? null
                    : (value) => onWeightChanged!(index, value),
                onRepsChanged: onRepsChanged == null
                    ? null
                    : (value) => onRepsChanged!(index, value),
                onIncrementWeight: onIncrementWeight == null
                    ? null
                    : () => onIncrementWeight!(index),
                onDecrementWeight: onDecrementWeight == null
                    ? null
                    : () => onDecrementWeight!(index),
                onIncrementReps: onIncrementReps == null
                    ? null
                    : () => onIncrementReps!(index),
                onDecrementReps: onDecrementReps == null
                    ? null
                    : () => onDecrementReps!(index),
                onToggleCompleted: onToggleCompleted == null
                    ? null
                    : () => onToggleCompleted!(index),
                onRemove: onRemoveSet == null
                    ? null
                    : () => onRemoveSet!(index),
              ),
              if (index < sets.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TrackerGlassButton(
              label: 'Agregar serie',
              icon: Icons.add_rounded,
              onPressed: onAddSet,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerSetRow extends StatefulWidget {
  const _TrackerSetRow({
    super.key,
    required this.item,
    this.onWeightChanged,
    this.onRepsChanged,
    this.onIncrementWeight,
    this.onDecrementWeight,
    this.onIncrementReps,
    this.onDecrementReps,
    this.onToggleCompleted,
    this.onRemove,
  });

  final TrackerSetItem item;
  final ValueChanged<String>? onWeightChanged;
  final ValueChanged<String>? onRepsChanged;
  final VoidCallback? onIncrementWeight;
  final VoidCallback? onDecrementWeight;
  final VoidCallback? onIncrementReps;
  final VoidCallback? onDecrementReps;
  final VoidCallback? onToggleCompleted;
  final VoidCallback? onRemove;

  @override
  State<_TrackerSetRow> createState() => _TrackerSetRowState();
}

class _TrackerSetRowState extends State<_TrackerSetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.item.weightText);
    _repsController = TextEditingController(text: widget.item.repsText);
  }

  @override
  void didUpdateWidget(covariant _TrackerSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.weightText != _weightController.text) {
      _weightController.value = TextEditingValue(
        text: widget.item.weightText,
        selection: TextSelection.collapsed(
          offset: widget.item.weightText.length,
        ),
      );
    }
    if (widget.item.repsText != _repsController.text) {
      _repsController.value = TextEditingValue(
        text: widget.item.repsText,
        selection: TextSelection.collapsed(offset: widget.item.repsText.length),
      );
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasAnyError = item.hasWeightError || item.hasRepsError;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.inner),
        color: item.completed
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: hasAnyError
              ? AppColors.dangerBorder
              : item.completed
              ? AppColors.glassBorderStrong
              : AppColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TrackerTagChip(
                label: 'Serie ${item.order}',
                highlighted: item.completed,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PreviousSetReferenceView(
                    reference: item.previousReference,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TrackerIconControl(
                icon: item.completed
                    ? Icons.check_rounded
                    : Icons.radio_button_unchecked_rounded,
                tooltip: item.completed
                    ? 'Marcar serie como pendiente'
                    : 'Marcar serie como completada',
                selected: item.completed,
                onPressed: widget.onToggleCompleted,
              ),
              const SizedBox(width: 6),
              TrackerIconControl(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Eliminar serie',
                destructive: true,
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: WorkoutStepperField(
                  label: 'Peso (kg)',
                  controller: _weightController,
                  hasError: item.hasWeightError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: WorkoutInputFormatters.decimal,
                  decrementTooltip: 'Disminuir peso',
                  incrementTooltip: 'Aumentar peso',
                  onChanged: widget.onWeightChanged,
                  onDecrement: widget.onDecrementWeight,
                  onIncrement: widget.onIncrementWeight,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: WorkoutStepperField(
                  label: 'Repeticiones',
                  controller: _repsController,
                  hasError: item.hasRepsError,
                  inputFormatters: WorkoutInputFormatters.integer,
                  decrementTooltip: 'Disminuir repeticiones',
                  incrementTooltip: 'Aumentar repeticiones',
                  onChanged: widget.onRepsChanged,
                  onDecrement: widget.onDecrementReps,
                  onIncrement: widget.onIncrementReps,
                ),
              ),
            ],
          ),
          if (item.errorText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.errorText!,
              style: AppTypography.body.copyWith(
                fontSize: 12,
                color: AppColors.dangerText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
