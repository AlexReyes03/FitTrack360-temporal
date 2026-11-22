import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../state/progress_view_state.dart';
import 'progress_section_shell.dart';

/// Tarjeta Liquid Glass de comparación visual antes/después (Inicial vs Actual).
class ProgressPhotoComparisonCard extends StatelessWidget {
  const ProgressPhotoComparisonCard({
    super.key,
    required this.status,
    this.initialSlot,
    this.currentSlot,
    this.onCompareFullScreen,
    this.onAddPhoto,
    this.onRetry,
  });

  final ProgressSectionStatus status;
  final ProgressPhotoPreviewSlot? initialSlot;
  final ProgressPhotoPreviewSlot? currentSlot;
  final VoidCallback? onCompareFullScreen;
  final VoidCallback? onAddPhoto;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final hasAnyPhoto = initialSlot != null || currentSlot != null;
    final effectiveStatus = status == ProgressSectionStatus.data && !hasAnyPhoto
        ? ProgressSectionStatus.empty
        : status;

    return ProgressSectionShell(
      title: 'Comparación de fotos',
      subtitle: 'Vista lado a lado: Inicial vs Actual',
      status: effectiveStatus,
      emptyTitle: 'Sin fotos para comparar',
      emptyDescription:
          'Agrega una foto inicial y una reciente para comparar tu avance.',
      emptyActionLabel: onAddPhoto == null ? null : 'Agregar foto',
      onEmptyAction: onAddPhoto,
      errorMessage: 'No se pudo cargar la comparación de fotos.',
      onRetry: onRetry,
      skeletonHeight: 184,
      trailing:
          effectiveStatus == ProgressSectionStatus.data &&
              onCompareFullScreen != null
          ? ProgressGlassActionPill(
              label: 'Ver detalle',
              onPressed: onCompareFullScreen,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final initialTile = _PhotoComparisonSlotTile(
                fallbackLabel: 'Inicial',
                slot: initialSlot,
                onAddPhoto: onAddPhoto,
              );
              final currentTile = _PhotoComparisonSlotTile(
                fallbackLabel: 'Actual',
                slot: currentSlot,
                onAddPhoto: onAddPhoto,
              );

              if (constraints.maxWidth < 320) {
                return Column(
                  children: [
                    initialTile,
                    const SizedBox(height: AppSpacing.sm),
                    currentTile,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: initialTile),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: currentTile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PhotoComparisonSlotTile extends StatelessWidget {
  const _PhotoComparisonSlotTile({
    required this.fallbackLabel,
    required this.slot,
    this.onAddPhoto,
  });

  final String fallbackLabel;
  final ProgressPhotoPreviewSlot? slot;
  final VoidCallback? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = slot != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.inner),
        color: AppColors.controlFillIdle,
        border: Border.all(
          color: hasPhoto ? AppColors.glassBorderStrong : AppColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  slot?.label ?? fallbackLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Spacer(),
              if (slot != null)
                Text(
                  slot!.weightLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.option),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: hasPhoto ? 0.12 : 0.05),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasPhoto
                            ? Icons.person_outline_rounded
                            : Icons.add_photo_alternate_outlined,
                        size: 32,
                        color: hasPhoto
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasPhoto
                            ? (slot!.caption ?? 'Foto registrada')
                            : 'Sin foto aún',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!hasPhoto && onAddPhoto != null) ...[
                        const SizedBox(height: 8),
                        ProgressGlassActionPill(
                          label: 'Agregar',
                          onPressed: onAddPhoto,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slot?.dateLabel ?? 'Pendiente',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
