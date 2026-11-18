import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';

/// Etiqueta compacta del catálogo.
class ExerciseTag extends StatelessWidget {
  const ExerciseTag(this.label, {super.key, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.badge),
        color: highlight ? const Color(0x1FFFFFFF) : const Color(0x0DFFFFFF),
        border: Border.all(
          color: highlight
              ? AppColors.glassBorderStrong
              : AppColors.glassBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlight ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
