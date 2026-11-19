import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import 'tracker_controls.dart';

/// Modo visual de ubicación para la sesión (P2).
enum TrackerLocationMode { gps, manualZone }

/// Sección P2 al final del tracker: selector visual GPS vs zona manual (solo UI).
class TrackerLocationSection extends StatelessWidget {
  const TrackerLocationSection({
    super.key,
    required this.mode,
    required this.manualZoneController,
    this.gpsStatusLabel = 'Sin ubicación capturada todavía',
    this.onModeChanged,
    this.onRequestGps,
    this.onManualZoneChanged,
  });

  final TrackerLocationMode mode;
  final TextEditingController manualZoneController;
  final String gpsStatusLabel;
  final ValueChanged<TrackerLocationMode>? onModeChanged;
  final VoidCallback? onRequestGps;
  final ValueChanged<String>? onManualZoneChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ubicación de entrenamiento',
                  style: AppTypography.cta.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const TrackerTagChip(label: 'Opcional'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Elige si deseas registrar el lugar por GPS o escribir la zona manualmente.',
            style: AppTypography.body.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TrackerGlassButton(
                  label: 'GPS',
                  icon: Icons.my_location_rounded,
                  compact: true,
                  selected: mode == TrackerLocationMode.gps,
                  onPressed: onModeChanged == null
                      ? null
                      : () => onModeChanged!(TrackerLocationMode.gps),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TrackerGlassButton(
                  label: 'Zona manual',
                  icon: Icons.edit_location_alt_outlined,
                  compact: true,
                  selected: mode == TrackerLocationMode.manualZone,
                  onPressed: onModeChanged == null
                      ? null
                      : () => onModeChanged!(TrackerLocationMode.manualZone),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (mode == TrackerLocationMode.gps)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.option),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gpsStatusLabel,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TrackerGlassButton(
                    label: 'Usar ubicación actual',
                    icon: Icons.gps_fixed_rounded,
                    compact: true,
                    onPressed: onRequestGps,
                  ),
                ],
              ),
            )
          else
            TextField(
              controller: manualZoneController,
              onChanged: onManualZoneChanged,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.5,
              ),
              cursorColor: AppColors.accentWhite,
              decoration: InputDecoration(
                hintText: 'Ej. Gimnasio Norte, Parque Central, Casa',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xB807080C),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
