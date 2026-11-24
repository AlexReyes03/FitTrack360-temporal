import 'package:flutter/material.dart';

import 'status_banner.dart';

/// Muestra un aviso efímero flotante con el estilo del DS y reemplaza al que
/// esté visible (no se encolan avisos viejos).
///
/// El fondo, la forma y el texto vienen de `snackBarTheme` en
/// `fitTrackDarkTheme`; [variant] sólo cambia el ícono y el color del texto
/// (misma paleta que [StatusBanner]).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showAppSnackBar(
  BuildContext context, {
  required String message,
  StatusBannerVariant variant = StatusBannerVariant.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  final palette = StatusBannerPalette.of(variant);
  return (messenger..hideCurrentSnackBar()).showSnackBar(
    SnackBar(
      key: ValueKey('app-snack-bar-${variant.name}'),
      duration: duration,
      content: Row(
        children: [
          ExcludeSemantics(
            child: Icon(palette.icon, color: palette.text, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: palette.text)),
          ),
        ],
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}
