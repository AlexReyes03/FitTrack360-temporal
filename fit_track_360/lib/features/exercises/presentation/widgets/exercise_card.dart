import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../data/exercise.dart';
import '../../data/exercise_labels.dart';
import 'exercise_media_view.dart';
import 'exercise_tag.dart';

/// Tarjeta del catálogo con miniatura, nombre, etiquetas y atribución.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({super.key, required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassSurface(
        padding: const EdgeInsets.all(AppSpacing.sm),
        radius: AppRadii.inner,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: ExerciseMediaView(exercise: exercise),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (exercise.nameEs != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      exercise.nameEs!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ExerciseTag(translateBodyPart(exercise.bodyPart)),
                      ExerciseTag(translateEquipment(exercise.equipment)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exercise.attribution,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
