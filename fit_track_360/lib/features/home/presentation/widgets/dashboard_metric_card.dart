import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import 'dashboard_block_shell.dart';

/// Modelo visual para la última métrica corporal en el dashboard.
class DashboardMetricData {
  const DashboardMetricData({
    required this.weightValue,
    required this.unit,
    required this.recordedAtLabel,
    required this.deltaLabel,
  });

  final String weightValue;
  final String unit;
  final String recordedAtLabel;
  final String deltaLabel;

  static const DashboardMetricData preview = DashboardMetricData(
    weightValue: '74.2',
    unit: 'kg',
    recordedAtLabel: 'Hace 2 días · 17 nov',
    deltaLabel: '-0.4 kg respecto al registro anterior',
  );
}

/// Bloque de última métrica corporal registrada (peso y fecha).
class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    super.key,
    this.status = DashboardBlockStatus.data,
    this.data = DashboardMetricData.preview,
    this.onRetry,
  });

  final DashboardBlockStatus status;
  final DashboardMetricData data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DashboardBlockShell(
      title: 'Última métrica',
      icon: Icons.monitor_weight_outlined,
      status: status,
      emptyMessage: 'Sin mediciones registradas todavía. Registra tu peso para seguir tu avance.',
      errorMessage: 'No pudimos cargar tu última métrica.',
      onRetry: onRetry,
      skeletonLines: 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      data.weightValue,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      data.unit,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.deltaLabel,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.option),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              data.recordedAtLabel,
              style: const TextStyle(
                color: AppColors.zinc200,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
