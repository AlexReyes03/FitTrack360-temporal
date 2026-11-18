import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../domain/exercise_reference.dart';

/// Referencia de la serie anterior, o el aviso cuando no hay historial.
class PreviousSetReferenceView extends StatelessWidget {
  const PreviousSetReferenceView({
    super.key,
    required this.reference,
    this.emptyLabel = 'Sin registro anterior',
  });

  final PreviousSetReference? reference;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final reference = this.reference;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.badge),
        color: AppColors.glassRimFaint,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        reference == null ? emptyLabel : 'Anterior: ${_format(reference)}',
        style: AppTypography.body.copyWith(
          fontSize: 12,
          color: reference == null
              ? AppColors.textMuted
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  String _format(PreviousSetReference reference) {
    final weight = reference.weightKg;
    if (weight == null) return '${reference.reps} reps';
    return '${_formatWeight(weight)} × ${reference.reps}';
  }

  String _formatWeight(double kg) {
    final rounded = kg.roundToDouble();
    final value = kg == rounded
        ? rounded.toStringAsFixed(0)
        : kg.toStringAsFixed(1);
    return '$value kg';
  }
}
