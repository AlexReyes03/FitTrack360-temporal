import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../domain/steps_sensor.dart';
import 'dashboard_block_shell.dart';
import 'dashboard_medical_notice.dart';
import 'dashboard_metric_card.dart';
import 'dashboard_nutrition_card.dart';
import 'dashboard_quick_actions.dart';
import 'dashboard_session_card.dart';
import 'dashboard_steps_card.dart';

/// Cuerpo scrollable del dashboard de Inicio compuesto por bloques Liquid Glass.
///
/// Todos los bloques tienen datos de preview en español (MX) y aceptan estados
/// visuales (`loading`, `data`, `empty`, `error`) más callbacks inyectables para
/// que Agente Lógica conecte ViewModels reales sin modificar el layout.
class HomeDashboardContent extends StatelessWidget {
  const HomeDashboardContent({
    super.key,
    this.displayName,
    this.nutritionStatus = DashboardBlockStatus.data,
    this.nutritionData = DashboardNutritionData.preview,
    this.onRetryNutrition,
    this.sessionStatus = DashboardBlockStatus.data,
    this.sessionData = DashboardSessionData.preview,
    this.onRetrySession,
    this.metricStatus = DashboardBlockStatus.data,
    this.metricData = DashboardMetricData.preview,
    this.onRetryMetric,
    this.stepsStatus = DashboardBlockStatus.data,
    this.stepsData = DashboardStepsData.preview,
    this.stepsUnavailable = false,
    this.stepsUnavailableReason,
    this.stepsNeedPermission = false,
    this.stepsCanOpenSettings = false,
    this.onRetrySteps,
    this.onEnableSteps,
    this.onOpenStepsSettings,
    this.onOpenWorkout,
    this.onOpenMeals,
    this.onOpenPhoto,
    this.onOpenProgress,
  });

  final String? displayName;

  final DashboardBlockStatus nutritionStatus;
  final DashboardNutritionData nutritionData;
  final VoidCallback? onRetryNutrition;

  final DashboardBlockStatus sessionStatus;
  final DashboardSessionData sessionData;
  final VoidCallback? onRetrySession;

  final DashboardBlockStatus metricStatus;
  final DashboardMetricData metricData;
  final VoidCallback? onRetryMetric;

  final DashboardBlockStatus stepsStatus;
  final DashboardStepsData stepsData;
  final bool stepsUnavailable;
  final StepsUnavailableReason? stepsUnavailableReason;
  final bool stepsNeedPermission;
  final bool stepsCanOpenSettings;
  final VoidCallback? onRetrySteps;
  final VoidCallback? onEnableSteps;
  final VoidCallback? onOpenStepsSettings;

  final VoidCallback? onOpenWorkout;
  final VoidCallback? onOpenMeals;
  final VoidCallback? onOpenPhoto;
  final VoidCallback? onOpenProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName == null ? 'Hola, bienvenido' : 'Hola, $displayName',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tu resumen diario de nutrición, entrenamiento y progreso.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DashboardQuickActions(
          onWorkoutTap: onOpenWorkout,
          onMealTap: onOpenMeals,
          onPhotoTap: onOpenPhoto,
        ),
        const SizedBox(height: AppSpacing.sm),
        DashboardNutritionCard(
          status: nutritionStatus,
          data: nutritionData,
          onRetry: onRetryNutrition,
          onOpenMeals: onOpenMeals,
        ),
        const SizedBox(height: AppSpacing.sm),
        DashboardSessionCard(
          status: sessionStatus,
          data: sessionData,
          onRetry: onRetrySession,
          onPrimaryAction: onOpenWorkout,
        ),
        const SizedBox(height: AppSpacing.sm),
        DashboardMetricCard(
          status: metricStatus,
          data: metricData,
          onRetry: onRetryMetric,
          onRegisterMetric: onOpenProgress,
        ),
        const SizedBox(height: AppSpacing.sm),
        DashboardStepsCard(
          status: stepsStatus,
          data: stepsData,
          isUnavailable: stepsUnavailable,
          unavailableReason: stepsUnavailableReason,
          needsPermission: stepsNeedPermission,
          canOpenSettings: stepsCanOpenSettings,
          onRetry: onRetrySteps,
          onEnable: onEnableSteps,
          onOpenSettings: onOpenStepsSettings,
        ),
        const SizedBox(height: AppSpacing.sm),
        const DashboardMedicalNotice(),
      ],
    );
  }
}
