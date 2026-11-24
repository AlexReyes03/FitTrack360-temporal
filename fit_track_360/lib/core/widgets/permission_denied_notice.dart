import 'package:flutter/material.dart';

import '../../design_system/components/primary_button.dart';
import '../../design_system/components/secondary_button.dart';
import '../../design_system/components/status_banner.dart';
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

    return StatusBanner(
      variant: StatusBannerVariant.warning,
      icon: icon,
      title: title,
      message: message,
      action: hasPrimaryAction || hasSecondaryAction
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPrimaryAction)
                  PrimaryButton(label: actionLabel!, onPressed: onAction),
                if (hasPrimaryAction && hasSecondaryAction)
                  const SizedBox(height: AppSpacing.xs),
                if (hasSecondaryAction)
                  SecondaryButton(
                    label: secondaryActionLabel!,
                    expand: true,
                    onPressed: onSecondaryAction,
                  ),
              ],
            )
          : null,
    );
  }
}
