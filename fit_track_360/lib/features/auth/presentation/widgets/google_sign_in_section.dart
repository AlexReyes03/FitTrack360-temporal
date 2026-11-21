import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';

/// Separador horizontal monocromo "o" para flujos de autenticacion.
class AuthOrDivider extends StatelessWidget {
  final String label;

  const AuthOrDivider({super.key, this.label = 'o'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1, color: AppColors.glassBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: AppTypography.caption),
        ),
        const Expanded(child: Divider(height: 1, color: AppColors.glassBorder)),
      ],
    );
  }
}

/// Bloque reutilizable con separador "o" y CTA de Google alineado al DS.
class GoogleAuthSection extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final bool isLoading;
  final bool enabled;
  final String label;
  final String loadingLabel;

  const GoogleAuthSection({
    super.key,
    this.onGooglePressed,
    this.isLoading = false,
    this.enabled = true,
    this.label = 'Continuar con Google',
    this.loadingLabel = 'Conectando con Google...',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthOrDivider(),
        const SizedBox(height: 16),
        GoogleSignInButton(
          onGooglePressed: onGooglePressed,
          isLoading: isLoading,
          enabled: enabled,
          label: label,
          loadingLabel: loadingLabel,
        ),
      ],
    );
  }
}

/// Boton secundario Liquid Glass (monocromo) para continuar con Google.
///
/// Soporta estados visuales `idle`, `pressed`, `loading` y `disabled` sin
/// acoplarse a Firebase Auth ni a `google_sign_in`.
class GoogleSignInButton extends StatefulWidget {
  final VoidCallback? onGooglePressed;
  final bool isLoading;
  final bool enabled;
  final String label;
  final String loadingLabel;

  const GoogleSignInButton({
    super.key,
    this.onGooglePressed,
    this.isLoading = false,
    this.enabled = true,
    this.label = 'Continuar con Google',
    this.loadingLabel = 'Conectando con Google...',
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _pressed = false;

  bool get _interactive => widget.enabled && !widget.isLoading;

  static const _idleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.glassFillStrong, AppColors.glassFillSoft],
  );

  static const _pressedGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.glassFillPressedStrong, AppColors.glassFillPressedSoft],
  );

  void _handleTap() {
    if (!_interactive) return;
    widget.onGooglePressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showDisabledOpacity = !widget.enabled && !widget.isLoading;
    final semanticLabel = widget.isLoading ? widget.loadingLabel : widget.label;

    return Semantics(
      button: true,
      enabled: _interactive,
      label: semanticLabel,
      child: Opacity(
        opacity: showDisabledOpacity ? 0.55 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _interactive
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: _interactive
              ? (_) => setState(() => _pressed = false)
              : null,
          onTapCancel: _interactive
              ? () => setState(() => _pressed = false)
              : null,
          onTap: _interactive ? _handleTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _pressed ? -1 : 0, 0),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              gradient: _pressed ? _pressedGradient : _idleGradient,
              border: Border.all(
                color: _pressed
                    ? AppColors.glassBorderPressed
                    : AppColors.glassBorderStrong,
              ),
              boxShadow: [
                BoxShadow(
                  color: _pressed
                      ? AppColors.glassFillStrong
                      : AppColors.glassFillSoft,
                  blurRadius: _pressed ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.glassHighlight,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        if (widget.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textPrimary,
                              ),
                            ),
                          )
                        else
                          const _MonochromeGoogleMark(),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            widget.isLoading
                                ? widget.loadingLabel
                                : widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.secondaryCta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonochromeGoogleMark extends StatelessWidget {
  const _MonochromeGoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.glassFillStrong,
        border: Border.all(color: AppColors.glassMarkBorder),
      ),
      child: const Text('G', style: AppTypography.badgeGlyph),
    );
  }
}
