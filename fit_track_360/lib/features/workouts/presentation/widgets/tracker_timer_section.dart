import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import 'tracker_controls.dart';

/// Bloque visual de cronómetro de sesión y descanso (sin Timer de negocio).
class TrackerTimerSection extends StatelessWidget {
  const TrackerTimerSection({
    super.key,
    required this.elapsedLabel,
    required this.isTimerRunning,
    required this.restRemainingLabel,
    required this.isRestRunning,
    required this.selectedRestSeconds,
    this.restPresetSeconds = const [60, 90, 120],
    this.onToggleTimer,
    this.onResetTimer,
    this.onToggleRestTimer,
    this.onResetRestTimer,
    this.onSelectRestPreset,
  });

  final String elapsedLabel;
  final bool isTimerRunning;
  final String restRemainingLabel;
  final bool isRestRunning;
  final int selectedRestSeconds;
  final List<int> restPresetSeconds;
  final VoidCallback? onToggleTimer;
  final VoidCallback? onResetTimer;
  final VoidCallback? onToggleRestTimer;
  final VoidCallback? onResetRestTimer;
  final ValueChanged<int>? onSelectRestPreset;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cronómetro de sesión',
                  style: AppTypography.cta.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TrackerTagChip(
                label: isTimerRunning ? 'En curso' : 'En pausa',
                highlighted: isTimerRunning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(child: Text(elapsedLabel, style: AppTypography.timer)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TrackerGlassButton(
                  label: isTimerRunning ? 'Pausar' : 'Iniciar',
                  icon: isTimerRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  selected: isTimerRunning,
                  onPressed: onToggleTimer,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TrackerGlassButton(
                label: 'Reiniciar',
                icon: Icons.refresh_rounded,
                onPressed: onResetTimer,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.inner),
              color: AppColors.glassTileFill,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        'Descanso entre series',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      restRemainingLabel,
                      style: AppTypography.headline.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final seconds in restPresetSeconds)
                      TrackerGlassButton(
                        label: '${seconds}s',
                        compact: true,
                        selected: selectedRestSeconds == seconds,
                        onPressed: onSelectRestPreset == null
                            ? null
                            : () => onSelectRestPreset!(seconds),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TrackerGlassButton(
                        label: isRestRunning
                            ? 'Pausar descanso'
                            : 'Iniciar descanso',
                        icon: isRestRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        compact: true,
                        selected: isRestRunning,
                        onPressed: onToggleRestTimer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    TrackerIconControl(
                      icon: Icons.replay_rounded,
                      tooltip: 'Reiniciar descanso',
                      onPressed: onResetRestTimer,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
