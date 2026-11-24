import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import 'dashboard_block_shell.dart';

/// Bloque de accesos rápidos táctiles a entrenamiento, comida y foto de progreso.
///
/// En cuadrícula de tres columnas cuando la palabra más larga cabe entera en
/// cada tarjeta; si no (pantallas estrechas o texto grande), pasa a una fila
/// por acceso para no partir palabras.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    super.key,
    this.onWorkoutTap,
    this.onMealTap,
    this.onPhotoTap,
  });

  final VoidCallback? onWorkoutTap;
  final VoidCallback? onMealTap;
  final VoidCallback? onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.fitness_center_rounded,
        label: 'Entrenar',
        onTap: onWorkoutTap,
      ),
      _QuickAction(
        icon: Icons.restaurant_menu_rounded,
        label: 'Comida',
        onTap: onMealTap,
      ),
      _QuickAction(
        icon: Icons.photo_camera_outlined,
        label: 'Foto progreso',
        onTap: onPhotoTap,
      ),
    ];
    return DashboardBlockShell(
      title: 'Accesos rápidos',
      icon: Icons.bolt_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gaps = AppSpacing.xs * (actions.length - 1);
          final tileWidth = (constraints.maxWidth - gaps) / actions.length;
          final labelWidth = tileWidth - _tileHorizontalPadding * 2 - 2;
          final fitsAsGrid = _longestWordWidth(context, actions) <= labelWidth;
          if (!fitsAsGrid) {
            // Sin espacio para que cada palabra quepa entera: una fila por
            // acceso, así ninguna etiqueta se parte a mitad de palabra.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.xs),
                  _QuickActionTile(action: actions[i], compact: true),
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(child: _QuickActionTile(action: actions[i])),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Ancho de la palabra más larga de todas las etiquetas con la escala de
  /// texto del usuario.
  static double _longestWordWidth(
    BuildContext context,
    List<_QuickAction> actions,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final action in actions) {
      for (final word in action.label.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: _labelStyle),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
    }
    return widest;
  }
}

const double _tileHorizontalPadding = 8;

const TextStyle _labelStyle = TextStyle(
  color: AppColors.zinc200,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  height: 1.2,
);

class _QuickAction {
  const _QuickAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action, this.compact = false});

  final _QuickAction action;

  /// Fila horizontal (ícono + etiqueta) para anchos donde la cuadrícula no
  /// deja espacio a la palabra más larga.
  final bool compact;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.action.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.action.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
          constraints: BoxConstraints(minHeight: widget.compact ? 48 : 84),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 14 : _tileHorizontalPadding,
            vertical: widget.compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.option),
            color: _pressed
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.045),
            border: Border.all(
              color: _pressed
                  ? AppColors.glassBorderStrong
                  : AppColors.glassBorder,
            ),
          ),
          child: widget.compact
              ? Row(
                  children: [
                    Icon(
                      widget.action.icon,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.action.label, style: _labelStyle),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.action.icon,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.action.label,
                      textAlign: TextAlign.center,
                      style: _labelStyle,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
