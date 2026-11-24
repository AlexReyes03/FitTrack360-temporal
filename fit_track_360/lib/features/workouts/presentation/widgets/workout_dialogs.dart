import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/components/primary_button.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import 'tracker_controls.dart';

/// Diálogo glass de confirmación con acción destructiva.
///
/// Devuelve `true` solo si la persona confirma. Privado del feature de
/// entrenamientos hasta que exista un diálogo del DS: migrar a DS en #222.
Future<bool> showWorkoutConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: GlassSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: confirmLabel,
              variant: PrimaryButtonVariant.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.xs),
            TrackerGlassButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

/// «¿Descartar cambios?» al salir de un formulario modificado.
Future<bool> showDiscardChangesDialog(BuildContext context) =>
    showWorkoutConfirmDialog(
      context,
      title: '¿Descartar cambios?',
      message: 'Si sales ahora, perderás lo que capturaste.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
    );

/// Confirmación al salir del tracker con una sesión activa.
Future<bool> showDiscardSessionDialog(BuildContext context) =>
    showWorkoutConfirmDialog(
      context,
      title: '¿Descartar la sesión?',
      message:
          'Se perderán el cronómetro, las series y las notas de esta sesión.',
      confirmLabel: 'Descartar sesión',
      cancelLabel: 'Seguir entrenando',
    );
