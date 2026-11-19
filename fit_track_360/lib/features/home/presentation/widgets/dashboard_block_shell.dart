import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_surface.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';

/// Estados visuales soportados por cada bloque del dashboard.
enum DashboardBlockStatus { loading, data, empty, error }

/// Contenedor Liquid Glass reutilizable para los bloques del dashboard.
///
/// Resuelve los estados visuales `loading`, `empty`, `error` y `data`
/// sin acoplarse a llamadas de red ni a ViewModels.
class DashboardBlockShell extends StatelessWidget {
  const DashboardBlockShell({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.status = DashboardBlockStatus.data,
    this.trailing,
    this.emptyMessage = 'Aún no hay datos registrados.',
    this.errorMessage = 'No pudimos cargar este bloque.',
    this.onRetry,
    this.skeletonLines = 3,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final DashboardBlockStatus status;
  final Widget? trailing;
  final String emptyMessage;
  final String errorMessage;
  final VoidCallback? onRetry;
  final int skeletonLines;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.nps),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(icon, size: 18, color: AppColors.accentSilver),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null && status == DashboardBlockStatus.data)
                trailing!,
            ],
          ),
          const SizedBox(height: 16),
          switch (status) {
            DashboardBlockStatus.loading => _SkeletonBody(lines: skeletonLines),
            DashboardBlockStatus.empty => _EmptyBody(message: emptyMessage),
            DashboardBlockStatus.error => _ErrorBody(
              message: errorMessage,
              onRetry: onRetry,
            ),
            DashboardBlockStatus.data => child,
          },
        ],
      ),
    );
  }
}

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    const widths = [0.62, 1.0, 0.78, 0.48];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        final factor = widths[index % widths.length];
        return Padding(
          padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : 10),
          child: FractionallySizedBox(
            widthFactor: factor,
            child: Container(
              height: index == 0 ? 22 : 13,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.badge),
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        message,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        color: AppColors.dangerFill,
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.dangerText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.dangerText,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          DashboardGlassPillButton(label: 'Reintentar', onTap: onRetry),
        ],
      ),
    );
  }
}

/// Botón pill compacto en estilo Liquid Glass con feedback táctil `pressed`.
class DashboardGlassPillButton extends StatefulWidget {
  const DashboardGlassPillButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  State<DashboardGlassPillButton> createState() =>
      _DashboardGlassPillButtonState();
}

class _DashboardGlassPillButtonState extends State<DashboardGlassPillButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            color: _pressed
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: _pressed
                  ? AppColors.glassBorderStrong
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 15, color: AppColors.textPrimary),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
