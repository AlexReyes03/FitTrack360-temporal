import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design_system/components/primary_button.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';

/// Aviso visual no bloqueante para estados de permiso denegado (P2/O5).
///
/// Widget puramente presentacional con estética Liquid Glass (variante Warning
/// de StatusBanner). No invoca plugins de permisos ni navega; todas las
/// acciones se inyectan mediante callbacks opcionales.
class PermissionDeniedNotice extends StatelessWidget {
  const PermissionDeniedNotice({
    super.key,
    this.title = 'Permiso denegado',
    this.message =
        'Puedes continuar usando la selección manual de zona o habilitar el '
        'permiso desde los ajustes del dispositivo.',
    this.icon = Icons.location_off_rounded,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final hasPrimaryAction = actionLabel != null && actionLabel!.isNotEmpty;
    final hasSecondaryAction =
        secondaryActionLabel != null && secondaryActionLabel!.isNotEmpty;

    return Semantics(
      container: true,
      liveRegion: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.banner),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.warningFill,
              borderRadius: BorderRadius.circular(AppRadii.banner),
              border: Border.all(color: AppColors.warningBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          icon,
                          color: AppColors.warningText,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.warningText,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: const TextStyle(
                                color: AppColors.warningText,
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasPrimaryAction) ...[
                    const SizedBox(height: 14),
                    PrimaryButton(label: actionLabel!, onPressed: onAction),
                  ],
                  if (hasSecondaryAction) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _SecondaryGlassButton(
                      label: secondaryActionLabel!,
                      onPressed: onSecondaryAction,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryGlassButton extends StatelessWidget {
  const _SecondaryGlassButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: AppColors.glassBorderStrong),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.zinc200,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
