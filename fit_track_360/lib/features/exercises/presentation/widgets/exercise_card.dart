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
///
/// El título es `nameEs ?? name`; si hay traducción, el nombre original va
/// como subtítulo. Es un botón accesible con efecto de toque (InkWell).
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({super.key, required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  static const double _thumbnailSize = 72;

  @override
  Widget build(BuildContext context) {
    final title = exercise.nameEs ?? exercise.name;
    final originalName = exercise.nameEs == null ? null : exercise.name;
    final bodyPart = translateBodyPart(exercise.bodyPart);
    final equipment = translateEquipment(exercise.equipment);

    return Semantics(
      button: true,
      label: '$title, $bodyPart, $equipment',
      excludeSemantics: true,
      onTap: onTap,
      child: GlassSurface(
        padding: EdgeInsets.zero,
        radius: AppRadii.inner,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.inner),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _thumbnailSize,
                    height: _thumbnailSize,
                    child: ExerciseMediaView(
                      exercise: exercise,
                      decodeWidth: _thumbnailSize,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        if (originalName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            originalName,
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
                            ExerciseTag(bodyPart),
                            ExerciseTag(equipment),
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
          ),
        ),
      ),
    );
  }
}
