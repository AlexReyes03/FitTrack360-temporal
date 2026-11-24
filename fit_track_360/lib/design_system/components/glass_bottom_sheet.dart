import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import 'glass_dialog.dart';

/// Abre una hoja modal inferior oscura con borde glass, asa de arrastre y
/// título opcional. El contenido respeta el área segura inferior.
///
/// Para listas de opciones (p. ej. «Cámara / Galería») usa
/// [GlassSheetAction] como hijos.
Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    backgroundColor: AppColors.bgMid,
    barrierColor: glassBarrierColor,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          0,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Semantics(
                  header: true,
                  child: Text(title, style: GlassDialog.titleStyle),
                ),
              ),
            ],
            Flexible(child: builder(sheetContext)),
          ],
        ),
      ),
    ),
  );
}

/// Fila de opción de una hoja glass: ícono + etiqueta, 56 dp de alto.
class GlassSheetAction extends StatelessWidget {
  const GlassSheetAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.dangerText : AppColors.textPrimary;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.option),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
