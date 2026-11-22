import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../state/progress_view_state.dart';

/// Contenedor Liquid Glass reutilizable para secciones de progreso con estados
/// visuales loading, data, empty y error.
class ProgressSectionShell extends StatelessWidget {
  const ProgressSectionShell({
    super.key,
    required this.title,
    required this.status,
    required this.child,
    this.subtitle,
    this.trailing,
    this.emptyTitle = 'Sin datos todavía',
    this.emptyDescription = 'Cuando registres tu avance, aparecerá aquí.',
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorMessage = 'No se pudo cargar esta sección.',
    this.onRetry,
    this.skeletonHeight = 112,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final ProgressSectionStatus status;
  final Widget child;
  final String emptyTitle;
  final String emptyDescription;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final String errorMessage;
  final VoidCallback? onRetry;
  final double skeletonHeight;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          switch (status) {
            ProgressSectionStatus.loading => _SectionSkeleton(
              height: skeletonHeight,
            ),
            ProgressSectionStatus.data => child,
            ProgressSectionStatus.empty => _SectionEmpty(
              title: emptyTitle,
              description: emptyDescription,
              actionLabel: emptyActionLabel,
              onAction: onEmptyAction,
            ),
            ProgressSectionStatus.error => _SectionError(
              message: errorMessage,
              onRetry: onRetry,
            ),
          },
        ],
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBar(widthFactor: 0.45, height: 14),
        const SizedBox(height: 10),
        _SkeletonBar(
          widthFactor: 1,
          height: height > 48 ? height - 38 : 32,
          radius: AppRadii.inner,
        ),
        const SizedBox(height: 10),
        _SkeletonBar(widthFactor: 0.65, height: 12),
      ],
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.widthFactor,
    required this.height,
    this.radius = AppRadii.badge,
  });

  final double widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.glassRimFaint),
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.inner),
        color: AppColors.controlFillIdle,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTypography.body.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            ProgressGlassActionPill(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.banner),
        color: AppColors.dangerFill,
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.dangerText,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.dangerText,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppSpacing.xs),
            ProgressGlassActionPill(label: 'Reintentar', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

/// Botón pill secundario sobre superficie glass.
class ProgressGlassActionPill extends StatelessWidget {
  const ProgressGlassActionPill({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.glassBorderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: AppColors.textPrimary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
