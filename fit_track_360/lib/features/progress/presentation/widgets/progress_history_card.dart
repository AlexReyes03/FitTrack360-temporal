import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../state/progress_view_state.dart';
import 'progress_section_shell.dart';

/// Lista Liquid Glass con historial de peso y diferencia frente a la semana previa.
class ProgressHistoryCard extends StatelessWidget {
  const ProgressHistoryCard({
    super.key,
    required this.status,
    required this.entries,
    this.onEntryTap,
    this.onRetry,
  });

  final ProgressSectionStatus status;
  final List<ProgressHistoryEntry> entries;
  final ValueChanged<ProgressHistoryEntry>? onEntryTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus =
        status == ProgressSectionStatus.data && entries.isEmpty
        ? ProgressSectionStatus.empty
        : status;

    return ProgressSectionShell(
      title: 'Historial de registros',
      subtitle: 'Comparado contra la semana previa',
      status: effectiveStatus,
      emptyTitle: 'Sin registros anteriores',
      emptyDescription:
          'Tus check-ins de peso y su variación semanal aparecerán aquí.',
      errorMessage: 'No se pudo cargar el historial de progreso.',
      onRetry: onRetry,
      skeletonHeight: 148,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _HistoryRow(
              entry: entries[i],
              onTap: onEntryTap == null ? null : () => onEntryTap!(entries[i]),
            ),
            if (i < entries.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, this.onTap});

  final ProgressHistoryEntry entry;
  final VoidCallback? onTap;

  String _formatDiff(double? diff) {
    if (diff == null) return 'Base';
    if (diff.abs() < 0.05) return 'Sin cambio';
    final sign = diff > 0 ? '+' : '';
    return '$sign${diff.toStringAsFixed(1)} kg vs sem. ant.';
  }

  @override
  Widget build(BuildContext context) {
    final diffText = _formatDiff(entry.weeklyDiffKg);
    final isPositiveTrend =
        entry.weeklyDiffKg != null && entry.weeklyDiffKg!.abs() >= 0.05;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.inner),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.inner),
            color: AppColors.controlFillIdle,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.dateLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.weightKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.badge),
                      color: isPositiveTrend
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(
                      diffText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
