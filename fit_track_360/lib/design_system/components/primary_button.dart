import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_typography.dart';

/// Variante visual de [PrimaryButton].
enum PrimaryButtonVariant { primary, destructive }

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonVariant variant;

  /// Muestra un spinner y bloquea toques (evita el doble envío) sin el look
  /// deshabilitado: la acción sigue en curso, no está prohibida.
  final bool isLoading;

  /// Etiqueta durante la carga (p. ej. «Enviando…»); por defecto [label].
  final String? loadingLabel;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PrimaryButtonVariant.primary,
    this.isLoading = false,
    this.loadingLabel,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  static const _idleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.accentWhite, AppColors.zinc200, AppColors.accentSilver],
  );

  static const _pressedGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.accentWhite, Color(0xFFF4F4F5), AppColors.zinc200],
  );

  static const _destructiveIdleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.dangerSolidTop,
      AppColors.dangerSolidMid,
      AppColors.dangerSolidBottom,
    ],
  );

  static const _destructivePressedGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.dangerSolidPressedTop,
      AppColors.dangerSolidTop,
      AppColors.dangerSolidMid,
    ],
  );

  @override
  void didUpdateWidget(PrimaryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pressed && (widget.onPressed == null || widget.isLoading)) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.isLoading ? null : widget.onPressed;
    final enabled = action != null;
    final destructive = widget.variant == PrimaryButtonVariant.destructive;

    final gradient = destructive
        ? (_pressed ? _destructivePressedGradient : _destructiveIdleGradient)
        : (_pressed ? _pressedGradient : _idleGradient);
    final borderColor = destructive
        ? AppColors.dangerSolidRim
        : Colors.white.withValues(alpha: 0.85);
    final shadowColor = destructive
        ? AppColors.dangerSolidShadow
        : Colors.white.withValues(alpha: 0.18);
    final labelStyle = destructive
        ? AppTypography.cta.copyWith(color: AppColors.accentWhite)
        : AppTypography.cta;

    final label = widget.isLoading
        ? (widget.loadingLabel ?? widget.label)
        : widget.label;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: action,
      excludeSemantics: true,
      child: Opacity(
        opacity: widget.onPressed != null ? 1 : 0.55,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: action,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _pressed ? -1 : 0, 0),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              gradient: gradient,
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox.square(
                    key: const ValueKey('primary-button-spinner'),
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: labelStyle.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
