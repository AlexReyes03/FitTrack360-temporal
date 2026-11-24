import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_typography.dart';

/// Tamaño de [SecondaryButton].
///
/// - [normal]: 48 dp de alto, etiqueta `secondaryCta`. Acciones de formulario
///   o diálogo («Cancelar», «Abrir ajustes»).
/// - [compact]: pill de 36 dp de alto visual dentro de un área táctil de
///   48 dp. Acciones en tarjetas, filtros y banners («Reintentar», «Ver todo»).
enum SecondaryButtonSize { normal, compact }

/// Variante de color de [SecondaryButton].
enum SecondaryButtonVariant { neutral, destructive }

/// Botón secundario Liquid Glass (pill) con estados Pressed, Selected,
/// Disabled y Loading.
///
/// Reemplaza a los botones glass privados de cada feature
/// (`TrackerGlassButton`, `ProgressGlassActionPill`, `DashboardGlassPillButton`,
/// `ProfileGlassButton`, `ExercisePillButton`, `_SecondaryGlassButton`,
/// `_RetryButton`, `_ActionPillButton`).
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = SecondaryButtonSize.normal,
    this.variant = SecondaryButtonVariant.neutral,
    this.selected = false,
    this.isLoading = false,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;

  /// `null` deshabilita el botón (opacidad 0.55).
  final VoidCallback? onPressed;
  final IconData? icon;
  final SecondaryButtonSize size;
  final SecondaryButtonVariant variant;

  /// Opción elegida en un grupo (relleno blanco, texto `textOnAccent`).
  final bool selected;

  /// Muestra un indicador y bloquea toques mientras la acción está en curso.
  final bool isLoading;

  /// Ocupa todo el ancho disponible (p. ej. bajo un `PrimaryButton`).
  final bool expand;

  /// Etiqueta para lectores de pantalla si debe ser más explícita que
  /// [label] (p. ej. «Reintentar conexión»).
  final String? semanticLabel;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _pressed = false;

  /// Mínimo accesible del área táctil en ambos tamaños.
  static const double _minTapTarget = 48;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(SecondaryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pressed && (widget.onPressed == null || widget.isLoading)) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.size == SecondaryButtonSize.compact;
    final destructive = widget.variant == SecondaryButtonVariant.destructive;
    final action = widget.isLoading ? null : widget.onPressed;
    final enabled = action != null;

    final Color foreground;
    final Color border;
    final Gradient? gradient;
    final Color? fill;
    if (destructive) {
      foreground = AppColors.dangerText;
      border = _pressed ? AppColors.dangerSolidRim : AppColors.dangerBorder;
      fill = AppColors.dangerFill;
      gradient = null;
    } else if (widget.selected) {
      foreground = AppColors.textOnAccent;
      border = AppColors.accentSilver;
      fill = AppColors.accentWhite;
      gradient = null;
    } else {
      foreground = AppColors.textPrimary;
      border = _pressed
          ? AppColors.glassBorderPressed
          : AppColors.glassBorderStrong;
      fill = null;
      gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _pressed
            ? const [
                AppColors.glassFillPressedStrong,
                AppColors.glassFillPressedSoft,
              ]
            : const [AppColors.glassFillStrong, AppColors.glassFillSoft],
      );
    }

    final textStyle = compact
        ? AppTypography.secondaryCta.copyWith(
            fontSize: 13,
            height: 1.2,
            color: foreground,
          )
        : AppTypography.secondaryCta.copyWith(color: foreground);
    final iconSize = compact ? 15.0 : 18.0;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox.square(
            dimension: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          ),
          const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: iconSize, color: foreground),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textStyle,
          ),
        ),
      ],
    );

    final pill = AnimatedContainer(
      key: const ValueKey('secondary-button-surface'),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _pressed ? -1 : 0, 0),
      constraints: BoxConstraints(
        minHeight: compact ? 36 : _minTapTarget,
        minWidth: compact ? 0 : 88,
      ),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      alignment: widget.expand ? Alignment.center : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        color: fill,
        gradient: gradient,
        border: Border.all(color: border),
      ),
      child: content,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected ? true : null,
      label: widget.semanticLabel ?? widget.label,
      onTap: action,
      excludeSemantics: true,
      child: Opacity(
        opacity: widget.onPressed == null ? 0.55 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: () => _setPressed(false),
          onTap: action,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: _minTapTarget,
              minWidth: widget.expand ? double.infinity : 0,
            ),
            child: Align(
              widthFactor: widget.expand ? null : 1,
              heightFactor: 1,
              child: pill,
            ),
          ),
        ),
      ),
    );
  }
}
