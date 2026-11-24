import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import 'dashboard_block_shell.dart';

/// Modelo visual para el bloque de sesión de entrenamiento en el dashboard.
class DashboardSessionData {
  const DashboardSessionData({
    required this.title,
    required this.relativeDate,
    required this.summary,
    required this.ctaLabel,
  });

  final String title;
  final String relativeDate;
  final String summary;
  final String ctaLabel;

  static const DashboardSessionData preview = DashboardSessionData(
    title: 'Tren superior · Fuerza',
    relativeDate: 'Hoy · 07:30',
    summary: '5 ejercicios · 18 series completadas',
    ctaLabel: 'Abrir entrenamiento',
  );
}

/// Bloque de sesión de hoy o última sesión registrada.
class DashboardSessionCard extends StatelessWidget {
  const DashboardSessionCard({
    super.key,
    this.status = DashboardBlockStatus.data,
    this.data = DashboardSessionData.preview,
    this.onRetry,
    this.onPrimaryAction,
  });

  final DashboardBlockStatus status;
  final DashboardSessionData data;
  final VoidCallback? onRetry;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return DashboardBlockShell(
      title: 'Sesión de entrenamiento',
      icon: Icons.fitness_center_outlined,
      status: status,
      emptyMessage: 'Aún no tienes sesiones registradas. Inicia un entrenamiento para ver tu actividad.',
      errorMessage: 'No pudimos cargar tu última sesión.',
      onRetry: onRetry,
      emptyActionLabel: 'Iniciar entrenamiento',
      onEmptyAction: onPrimaryAction,
      skeletonLines: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        data.relativeDate,
                        style: const TextStyle(
                          color: AppColors.zinc200,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data.summary,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: DashboardGlassPillButton(
              label: data.ctaLabel,
              icon: Icons.play_arrow_rounded,
              onTap: onPrimaryAction,
            ),
          ),
        ],
      ),
    );
  }
}
