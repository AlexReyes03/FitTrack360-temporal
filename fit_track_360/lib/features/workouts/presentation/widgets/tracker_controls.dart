import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';

/// Botón secundario Liquid Glass con estado táctil pressed/selected (sin hover).
class TrackerGlassButton extends StatefulWidget {
  const TrackerGlassButton({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.destructive = false,
    this.compact = false,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool destructive;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  State<TrackerGlassButton> createState() => _TrackerGlassButtonState();
}

class _TrackerGlassButtonState extends State<TrackerGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final foregroundColor = widget.destructive
        ? AppColors.dangerText
        : widget.selected
        ? AppColors.textOnAccent
        : AppColors.textPrimary;

    final borderColor = widget.destructive
        ? AppColors.dangerBorder
        : widget.selected
        ? Colors.white.withValues(alpha: 0.85)
        : _pressed
        ? AppColors.glassBorderStrong
        : AppColors.glassBorder;

    final backgroundColor = widget.destructive
        ? AppColors.dangerFill
        : widget.selected
        ? AppColors.accentWhite
        : _pressed
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.06);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? AppSpacing.sm : 16,
            vertical: widget.compact ? 8 : 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.option),
            color: backgroundColor,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.compact ? 16 : 18,
                  color: foregroundColor,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontSize: widget.compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Control táctil cuadrado/circular para acciones rápidas (+/-, check, eliminar).
class TrackerIconControl extends StatefulWidget {
  const TrackerIconControl({
    super.key,
    required this.icon,
    required this.tooltip,
    this.selected = false,
    this.destructive = false,
    this.size = 36,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final bool destructive;
  final double size;
  final VoidCallback? onPressed;

  @override
  State<TrackerIconControl> createState() => _TrackerIconControlState();
}

class _TrackerIconControlState extends State<TrackerIconControl> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final foregroundColor = widget.destructive
        ? AppColors.dangerText
        : widget.selected
        ? AppColors.textOnAccent
        : AppColors.textPrimary;

    final backgroundColor = widget.destructive
        ? AppColors.dangerFill
        : widget.selected
        ? AppColors.accentWhite
        : _pressed
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.06);

    final borderColor = widget.destructive
        ? AppColors.dangerBorder
        : widget.selected
        ? Colors.white.withValues(alpha: 0.85)
        : _pressed
        ? AppColors.glassBorderStrong
        : AppColors.glassBorder;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: enabled
                ? () => setState(() => _pressed = false)
                : null,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.badge + 2),
                color: backgroundColor,
                border: Border.all(color: borderColor),
              ),
              child: Icon(widget.icon, size: 18, color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta/chip de estado o tag muscular estilo Liquid Glass.
class TrackerTagChip extends StatelessWidget {
  const TrackerTagChip({
    super.key,
    required this.label,
    this.highlighted = false,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        color: highlighted
            ? Colors.white.withValues(alpha: 0.14)
            : AppColors.glassRimFaint,
        border: Border.all(
          color: highlighted
              ? AppColors.glassBorderStrong
              : AppColors.glassBorder,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: highlighted ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
