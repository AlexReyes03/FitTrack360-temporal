import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../domain/steps_sensor.dart';
import 'dashboard_block_shell.dart';

/// Modelo visual para el bloque de pasos diarios (O5).
class DashboardStepsData {
  const DashboardStepsData({
    required this.stepsCount,
    required this.goalSteps,
    required this.subtitle,
  });

  final int stepsCount;
  final int goalSteps;
  final String subtitle;

  static const DashboardStepsData preview = DashboardStepsData(
    stepsCount: 6420,
    goalSteps: 8000,
    subtitle: 'Meta diaria de actividad',
  );
}

/// Bloque de pasos del día (O5).
///
/// Si [needsPermission] es `true`, explica el uso del sensor antes de pedir
/// el permiso del sistema con la acción «Mostrar mis pasos». Tras una
/// negativa muestra «Reintentar» y, si el sistema ya no vuelve a preguntar,
/// «Abrir ajustes».
class DashboardStepsCard extends StatelessWidget {
  const DashboardStepsCard({
    super.key,
    this.status = DashboardBlockStatus.data,
    this.data = DashboardStepsData.preview,
    this.isUnavailable = false,
    this.unavailableReason,
    this.needsPermission = false,
    this.canOpenSettings = false,
    this.onRetry,
    this.onEnable,
    this.onOpenSettings,
  });

  final DashboardBlockStatus status;
  final DashboardStepsData data;
  final bool isUnavailable;
  final StepsUnavailableReason? unavailableReason;
  final bool needsPermission;
  final bool canOpenSettings;
  final VoidCallback? onRetry;
  final VoidCallback? onEnable;
  final VoidCallback? onOpenSettings;

  static const permissionExplanation =
      'Para mostrar tus pasos de hoy, FitTrack360 lee el sensor de actividad '
      'física del teléfono. El conteo se queda en tu dispositivo.';

  static String unavailableMessageFor(StepsUnavailableReason? reason) {
    return switch (reason) {
      StepsUnavailableReason.denied =>
        'No diste permiso para leer tus pasos. Toca «Reintentar» para '
            'volver a intentarlo. Puedes activarlo después desde los ajustes '
            'del teléfono.',
      StepsUnavailableReason.blocked =>
        'El acceso a la actividad física está desactivado. '
            'Puedes activarlo después desde los ajustes del teléfono.',
      _ =>
        'Contador de pasos no disponible en este dispositivo o sin permiso '
            'activo.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final progress = data.goalSteps <= 0
        ? 0.0
        : (data.stepsCount / data.goalSteps).clamp(0.0, 1.0);

    return DashboardBlockShell(
      title: 'Pasos de hoy',
      icon: Icons.directions_walk_rounded,
      status: status,
      emptyMessage: 'Todavía no se registran pasos en el día de hoy.',
      errorMessage: 'No pudimos leer tus pasos diarios.',
      onRetry: onRetry,
      skeletonLines: 2,
      child: needsPermission
          ? _PermissionPrompt(onEnable: onEnable)
          : isUnavailable
          ? _UnavailableNotice(
              message: unavailableMessageFor(unavailableReason),
              onRetry: onRetry,
              onOpenSettings: canOpenSettings ? onOpenSettings : null,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${data.stepsCount}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '/ ${data.goalSteps} pasos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: Container(
                    height: 7,
                    color: AppColors.controlTrack,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.accentWhite,
                              AppColors.accentSilver,
                            ],
                          ),
                        ),
                        child: const SizedBox(height: 7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({this.onEnable});

  final VoidCallback? onEnable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          DashboardStepsCard.permissionExplanation,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        DashboardGlassPillButton(
          label: 'Mostrar mis pasos',
          icon: Icons.directions_walk_rounded,
          onTap: onEnable,
        ),
      ],
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({
    required this.message,
    this.onRetry,
    this.onOpenSettings,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.sensors_off_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No disponible',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onRetry != null || onOpenSettings != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onRetry != null)
                  DashboardGlassPillButton(label: 'Reintentar', onTap: onRetry),
                if (onOpenSettings != null)
                  DashboardGlassPillButton(
                    label: 'Abrir ajustes',
                    icon: Icons.settings_outlined,
                    onTap: onOpenSettings,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
