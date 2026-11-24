import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';

/// Destino visual de la barra inferior Liquid Glass.
class GlassNavDestination {
  const GlassNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? tooltip;
}

/// Barra de navegacion inferior con look Liquid Glass dark (acento monocromo
/// blanco/plata, rim superior y destello especular). No depende de GoRouter.
class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<GlassNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.contentMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xC7000000),
                    blurRadius: 40,
                    offset: Offset(0, 16),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            color: const Color(0xAD0A0C12),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: [0.0, 0.5, 1.0],
                              colors: [
                                Color(0x18FFFFFF),
                                Color(0x08FFFFFF),
                                Color(0x0EFFFFFF),
                              ],
                            ),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: AppColors.glassRim),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 1,
                        child: FractionallySizedBox(
                          widthFactor: 0.84,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < destinations.length; i++)
                              Expanded(
                                child: _NavItemTile(
                                  destination: destinations[i],
                                  selected: i == selectedIndex,
                                  onTap: () => onDestinationSelected(i),
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
        ),
      ),
    );
  }
}

class _NavItemTile extends StatefulWidget {
  const _NavItemTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final GlassNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItemTile> createState() => _NavItemTileState();
}

class _NavItemTileState extends State<_NavItemTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final iconData = selected
        ? (widget.destination.selectedIcon ?? widget.destination.icon)
        : widget.destination.icon;

    final BoxDecoration decoration;
    if (selected) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            AppColors.accentSilver.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: AppColors.glassBorderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else if (_pressed) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        color: Colors.white.withValues(alpha: 0.075),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      );
    } else {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.option),
        border: Border.all(color: Colors.transparent),
      );
    }

    final color = selected ? AppColors.accentWhite : AppColors.textSecondary;
    final labelStyle = TextStyle(
      color: color,
      fontSize: _labelFontSize,
      height: 1.2,
      letterSpacing: -0.2,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );

    return Semantics(
      // container + excludeSemantics: un nodo por destino que se lee una sola
      // vez ("Inicio, botón, seleccionado") sin repetir el Text visible.
      container: true,
      button: true,
      selected: selected,
      label: widget.destination.tooltip ?? widget.destination.label,
      excludeSemantics: true,
      child: Tooltip(
        // Mantener presionado muestra el nombre completo si se recorta con
        // tamaños de texto grandes.
        message: widget.destination.label,
        excludeFromSemantics: true,
        triggerMode: TooltipTriggerMode.longPress,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: _minTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            decoration: decoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconData, size: 20, color: color),
                const SizedBox(height: 3),
                LayoutBuilder(
                  builder: (context, constraints) => _NavLabel(
                    text: widget.destination.label,
                    style: labelStyle,
                    maxWidth: constraints.maxWidth,
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

/// Tamano base de las etiquetas (11-12dp segun UX-06).
const double _labelFontSize = 11.5;

/// Minimo legible: con poco ancho la etiqueta puede reducirse hasta aqui,
/// nunca por debajo (antes `FittedBox(scaleDown)` la llevaba a ~8dp).
const double _labelMinFontSize = 11;

/// Tope del escalado de texto en la barra: con 6 destinos no cabe mas; el
/// nombre completo sigue disponible por lector de pantalla y tooltip.
const double _labelMaxTextScale = 1.3;

const double _minTapTarget = 48;

/// Etiqueta de un destino: respeta el `textScaler` del sistema (hasta
/// [_labelMaxTextScale]); si no cabe en el ancho, reduce la letra solo hasta
/// [_labelMinFontSize] y despues recorta con elipsis, sin desbordar.
class _NavLabel extends StatelessWidget {
  const _NavLabel({
    required this.text,
    required this.style,
    required this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1, maxScaleFactor: _labelMaxTextScale);
    final preferred = scaler.scale(style.fontSize!);
    var fontSize = preferred;
    if (maxWidth.isFinite) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontSize: preferred),
        ),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      if (width > maxWidth && width > 0) {
        fontSize = (preferred * maxWidth / width).clamp(
          _labelMinFontSize,
          preferred,
        );
      }
    }
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      // El escalado ya va incluido en fontSize.
      textScaler: TextScaler.noScaling,
      style: style.copyWith(fontSize: fontSize),
    );
  }
}
