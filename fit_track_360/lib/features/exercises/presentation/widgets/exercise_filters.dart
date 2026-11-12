import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../data/exercise_labels.dart';

/// Filtros por grupo muscular, equipo y músculo objetivo.
class ExerciseFilters extends StatelessWidget {
  const ExerciseFilters({
    super.key,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.onBodyPartChanged,
    required this.onEquipmentChanged,
    required this.onTargetChanged,
  });

  /// Valor de "sin filtro"; `DropdownButton` no acepta `null` como selección.
  static const String anyValue = '';

  final String? bodyPart;
  final String? equipment;
  final String? target;
  final ValueChanged<String?> onBodyPartChanged;
  final ValueChanged<String?> onEquipmentChanged;
  final ValueChanged<String?> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterDropdown(
          label: 'Músculo',
          value: bodyPart,
          optionLabel: translateBodyPart,
          options: bodyPartOptions,
          onChanged: onBodyPartChanged,
        ),
        _FilterDropdown(
          label: 'Equipo',
          value: equipment,
          optionLabel: translateEquipment,
          options: equipmentOptions,
          onChanged: onEquipmentChanged,
        ),
        _FilterDropdown(
          label: 'Objetivo',
          value: target,
          optionLabel: translateTarget,
          options: targetOptions,
          onChanged: onTargetChanged,
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final String Function(String) optionLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xB807080C),
              borderRadius: BorderRadius.circular(AppRadii.input),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value ?? ExerciseFilters.anyValue,
                isExpanded: true,
                dropdownColor: AppColors.bgMid,
                borderRadius: BorderRadius.circular(AppRadii.input),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                ),
                iconEnabledColor: AppColors.textMuted,
                items: [
                  const DropdownMenuItem<String>(
                    value: ExerciseFilters.anyValue,
                    child: Text('Todos'),
                  ),
                  for (final option in options)
                    DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        optionLabel(option),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (selected) => onChanged(
                  selected == null || selected == ExerciseFilters.anyValue
                      ? null
                      : selected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
