import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import 'dashboard_block_shell.dart';

/// Modelo visual para el bloque de nutrición diaria en el dashboard.
class DashboardNutritionData {
  const DashboardNutritionData({
    required this.consumedKcal,
    required this.targetKcal,
    required this.proteinGrams,
    required this.proteinTargetGrams,
    required this.carbsGrams,
    required this.carbsTargetGrams,
    required this.fatGrams,
    required this.fatTargetGrams,
  });

  final int consumedKcal;
  final int targetKcal;
  final int proteinGrams;
  final int proteinTargetGrams;
  final int carbsGrams;
  final int carbsTargetGrams;
  final int fatGrams;
  final int fatTargetGrams;

  static const DashboardNutritionData preview = DashboardNutritionData(
    consumedKcal: 1480,
    targetKcal: 2100,
    proteinGrams: 112,
    proteinTargetGrams: 150,
    carbsGrams: 148,
    carbsTargetGrams: 220,
    fatGrams: 46,
    fatTargetGrams: 65,
  );
}

/// Bloque de resumen diario de calorías y macronutrientes vs. meta.
class DashboardNutritionCard extends StatelessWidget {
  const DashboardNutritionCard({
    super.key,
    this.status = DashboardBlockStatus.data,
    this.data = DashboardNutritionData.preview,
    this.onRetry,
    this.onOpenMeals,
  });

  final DashboardBlockStatus status;
  final DashboardNutritionData data;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenMeals;

  double _ratio(int value, int target) {
    if (target <= 0) return 0;
    return (value / target).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (data.targetKcal - data.consumedKcal).clamp(0, 99999);
    final kcalRatio = _ratio(data.consumedKcal, data.targetKcal);

    return DashboardBlockShell(
      title: 'Nutrición de hoy',
      icon: Icons.restaurant_outlined,
      status: status,
      emptyMessage: 'Aún no registras comidas hoy. Agrega tu primera comida para ver tus macros.',
      errorMessage: 'No pudimos cargar tu resumen de nutrición.',
      onRetry: onRetry,
      emptyActionLabel: 'Registrar comida',
      onEmptyAction: onOpenMeals,
      trailing: onOpenMeals == null
          ? null
          : DashboardGlassPillButton(label: 'Ver diario', onTap: onOpenMeals),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${data.consumedKcal}',
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
                  '/ ${data.targetKcal} kcal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Restan $remaining kcal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GlassProgressBar(progress: kcalRatio, height: 8),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MacroMetricTile(
                  label: 'Proteína',
                  value: '${data.proteinGrams} / ${data.proteinTargetGrams} g',
                  progress: _ratio(data.proteinGrams, data.proteinTargetGrams),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _MacroMetricTile(
                  label: 'Carbs',
                  value: '${data.carbsGrams} / ${data.carbsTargetGrams} g',
                  progress: _ratio(data.carbsGrams, data.carbsTargetGrams),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _MacroMetricTile(
                  label: 'Grasas',
                  value: '${data.fatGrams} / ${data.fatTargetGrams} g',
                  progress: _ratio(data.fatGrams, data.fatTargetGrams),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroMetricTile extends StatelessWidget {
  const _MacroMetricTile({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _GlassProgressBar(progress: progress, height: 5),
        ],
      ),
    );
  }
}

class _GlassProgressBar extends StatelessWidget {
  const _GlassProgressBar({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        height: height,
        color: AppColors.controlTrack,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              gradient: const LinearGradient(
                colors: [AppColors.accentWhite, AppColors.accentSilver],
              ),
            ),
            child: SizedBox(height: height),
          ),
        ),
      ),
    );
  }
}
