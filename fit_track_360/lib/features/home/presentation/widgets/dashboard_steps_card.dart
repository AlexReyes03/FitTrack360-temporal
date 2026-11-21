import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
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

/// Bloque de pasos del día con estado visual dedicado cuando el sensor no está
/// disponible en el dispositivo (O5, solo UI sin `pedometer`).
class DashboardStepsCard extends StatelessWidget {
  const DashboardStepsCard({
    super.key,
    this.status = DashboardBlockStatus.data,
    this.data = DashboardStepsData.preview,
    this.isUnavailable = false,
    this.unavailableMessage = 'Contador de pasos no disponible en este dispositivo o sin permiso activo.',
    this.onRetry,
  });

  final DashboardBlockStatus status;
  final DashboardStepsData data;
  final bool isUnavailable;
  final String unavailableMessage;
  final VoidCallback? onRetry;

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
      child: isUnavailable
          ? Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.option),
                color: Colors.white.withValues(alpha: 0.035),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
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
                          unavailableMessage,
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
