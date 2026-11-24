import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Cabecera de pantalla secundaria (organismo del DS).
///
/// Anatomía: botón «Volver» glass de 48 dp → título `AppTypography.pageTitle`
/// (con subtítulo opcional en `textSecondary`) → acción [trailing] opcional.
///
/// El botón «Volver» resuelve la navegación así:
/// 1. Si hay [onBack], lo llama (la pantalla decide).
/// 2. Si no, y la ruta actual puede cerrarse, hace `Navigator.maybePop`.
/// 3. Si no hay a dónde regresar, llama a [onBackFallback] (p. ej.
///    `context.go('/app')`), para que el botón nunca quede sin efecto.
///
/// Se coloca en el slot `header` de `AppScaffoldTemplate` o de
/// `FormPageTemplate`.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
    this.onBack,
    this.onBackFallback,
    this.backTooltip = 'Volver',
  });

  final String title;
  final String? subtitle;

  /// Acción opcional a la derecha (p. ej. un `SecondaryButton` compacto).
  final Widget? trailing;

  /// `false` en pantallas raíz (pestañas) que no tienen a dónde regresar.
  final bool showBack;

  /// Reemplaza el comportamiento por defecto del botón «Volver».
  final VoidCallback? onBack;

  /// Destino cuando no hay ruta previa que cerrar (deep link, `go`).
  final VoidCallback? onBackFallback;

  final String backTooltip;

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.maybePop();
      return;
    }
    onBackFallback?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack) ...[
          GlassBackButton(
            tooltip: backTooltip,
            onPressed: () => _handleBack(context),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.pageTitle,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// Botón cuadrado glass de 48 dp con flecha de regreso y tooltip.
///
/// Es el control «Volver» de [PageHeader]; se expone para cabeceras que aún
/// no pueden usar el organismo completo (p. ej. barras de sesión activa).
class GlassBackButton extends StatefulWidget {
  const GlassBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Volver',
    this.icon = Icons.arrow_back_rounded,
  });

  /// Lado del área táctil y del vidrio (mínimo accesible de 48 dp).
  static const double size = 48;

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;

  @override
  State<GlassBackButton> createState() => _GlassBackButtonState();
}

class _GlassBackButtonState extends State<GlassBackButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.tooltip,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.tooltip,
        excludeFromSemantics: true,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: () => _setPressed(false),
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: GlassBackButton.size,
              height: GlassBackButton.size,
              transform: Matrix4.translationValues(0, _pressed ? -1 : 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.option),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _pressed
                      ? const [
                          AppColors.glassFillPressedStrong,
                          AppColors.glassFillPressedSoft,
                        ]
                      : const [
                          AppColors.glassFillStrong,
                          AppColors.glassFillSoft,
                        ],
                ),
                border: Border.all(
                  color: _pressed
                      ? AppColors.glassBorderPressed
                      : AppColors.glassBorderStrong,
                ),
              ),
              child: Icon(widget.icon, size: 22, color: AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
