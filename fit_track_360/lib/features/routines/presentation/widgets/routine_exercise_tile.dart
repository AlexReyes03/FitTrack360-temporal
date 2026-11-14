import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../data/routines_reader.dart';

/// Ejercicio del detalle con su ordinal visible y objetivos opcionales.
class RoutineExerciseTile extends StatelessWidget {
  const RoutineExerciseTile({
    super.key,
    required this.ordinal,
    required this.exercise,
  });

  final int ordinal;
  final RoutineExerciseSummary exercise;

  @override
  Widget build(BuildContext context) {
    final target = exercise.targetLabel;

    return GlassSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      radius: AppRadii.inner,
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassRimFaint,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              '$ordinal',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.displayName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (target != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    target,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
