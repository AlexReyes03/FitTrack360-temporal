import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../data/routines_reader.dart';

/// Tarjeta del listado con nombre, notas y métricas disponibles.
class RoutineCard extends StatelessWidget {
  const RoutineCard({super.key, required this.routine, required this.onTap});

  final RoutineSummary routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = <String>[
      if (routine.exerciseCount != null)
        _count(routine.exerciseCount!, 'ejercicio', 'ejercicios'),
      if (routine.targetSetCount != null)
        _count(routine.targetSetCount!, 'serie', 'series'),
    ];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassSurface(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        radius: AppRadii.inner,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.name.isEmpty ? 'Rutina sin nombre' : routine.name,
                    style: AppTypography.sectionTitle,
                  ),
                  if (routine.notes != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      routine.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ],
                  if (metrics.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        for (final metric in metrics)
                          Text(
                            metric,
                            style: AppTypography.meta.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

String _count(int value, String singular, String plural) {
  return '$value ${value == 1 ? singular : plural}';
}
