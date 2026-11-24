import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'glass_surface.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Velo detrás de diálogos y hojas modales. No hay token de scrim: se usa
/// `bgDeep` al 80 %. Cambiar a token `scrim` de #221.
final Color glassBarrierColor = AppColors.bgDeep.withValues(alpha: 0.8);

/// Ancho máximo de un diálogo glass en tabletas.
const double _dialogMaxWidth = 520;

/// Diálogo con superficie [GlassSurface] (sin `AlertDialog` Material).
///
/// Anatomía: título (20, w800) → mensaje en `textSecondary` y/o [content] →
/// [actions] apiladas a todo el ancho (la principal primero).
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  static const TextStyle titleStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
        child: GlassSurface(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(title, style: titleStyle)),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (content != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  content!,
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  for (final (index, action) in actions.indexed) ...[
                    if (index > 0) const SizedBox(height: AppSpacing.xs),
                    action,
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre un diálogo glass con el velo del DS. [builder] normalmente devuelve
/// un [GlassDialog].
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: glassBarrierColor,
    builder: builder,
  );
}

/// Confirmación de dos botones. Devuelve `true` sólo si se confirma; cerrar
/// con el velo, «Atrás» o [cancelLabel] devuelve `false`.
///
/// Con [destructive] la acción principal usa `PrimaryButtonVariant.destructive`
/// (rojo), para eliminar o descartar datos.
Future<bool> showGlassConfirmDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? message,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final confirmed = await showGlassDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassDialog(
      title: title,
      message: message,
      actions: [
        PrimaryButton(
          label: confirmLabel,
          variant: destructive
              ? PrimaryButtonVariant.destructive
              : PrimaryButtonVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        SecondaryButton(
          label: cancelLabel,
          expand: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
