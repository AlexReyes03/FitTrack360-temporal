import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// Variante de [StatusBanner].
///
/// - [warning]: ámbar. Avisos no bloqueantes (sin conexión, permiso denegado).
/// - [neutral]: blanco translúcido con ícono de información.
/// - [success]: misma paleta que [neutral] con palomita (confirmaciones:
///   «Guardado», «Te enviamos un correo»). El éxito no usa verde: el acento
///   del DS es monocromo.
/// - [danger]: rojo. Errores de envío o de carga.
enum StatusBannerVariant { warning, neutral, success, danger }

/// Colores e ícono por defecto de cada [StatusBannerVariant].
class StatusBannerPalette {
  const StatusBannerPalette({
    required this.fill,
    required this.border,
    required this.text,
    required this.icon,
  });

  final Color fill;
  final Color border;
  final Color text;
  final IconData icon;

  static StatusBannerPalette of(StatusBannerVariant variant) {
    return switch (variant) {
      StatusBannerVariant.warning => const StatusBannerPalette(
        fill: AppColors.warningFill,
        border: AppColors.warningBorder,
        text: AppColors.warningText,
        icon: Icons.info_outline_rounded,
      ),
      // El doc pide blanco @ 8 % / @ 20 %; se usan los tokens glass más
      // cercanos. Cambiar a tokens `neutralFill`/`neutralBorder` de #221.
      StatusBannerVariant.neutral => const StatusBannerPalette(
        fill: AppColors.glassFillStrong,
        border: AppColors.glassBorderStrong,
        text: AppColors.zinc100,
        icon: Icons.info_outline_rounded,
      ),
      StatusBannerVariant.success => const StatusBannerPalette(
        fill: AppColors.glassFillStrong,
        border: AppColors.glassBorderStrong,
        text: AppColors.zinc100,
        icon: Icons.check_circle_outline_rounded,
      ),
      StatusBannerVariant.danger => const StatusBannerPalette(
        fill: AppColors.dangerFill,
        border: AppColors.dangerBorder,
        text: AppColors.dangerText,
        icon: Icons.error_outline_rounded,
      ),
    };
  }
}

/// Aviso de estado del DS (Warning / Neutral / Success / Danger).
///
/// Anatomía: ícono → título opcional (15, w700) → mensaje (13.5) →
/// [action] opcional a todo el ancho debajo del texto, o [trailing] compacto
/// a la derecha (p. ej. «Reintentar» en el aviso sin conexión).
///
/// Es una live region por defecto: los lectores de pantalla anuncian el
/// texto cuando aparece o cambia. Pasa `liveRegion: false` para avisos
/// persistentes que no deben interrumpir.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.variant,
    required this.message,
    this.title,
    this.icon,
    this.action,
    this.trailing,
    this.liveRegion = true,
  });

  final StatusBannerVariant variant;
  final String message;
  final String? title;

  /// Reemplaza el ícono por defecto de la variante (p. ej. `wifi_off`).
  final IconData? icon;

  /// Acción(es) a todo el ancho bajo el texto.
  final Widget? action;

  /// Acción compacta alineada a la derecha del texto.
  final Widget? trailing;

  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final palette = StatusBannerPalette.of(variant);
    final hasTitle = title != null && title!.isNotEmpty;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasTitle) ...[
          Text(
            title!,
            style: TextStyle(
              color: palette.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          message,
          style: TextStyle(color: palette.text, fontSize: 13.5, height: 1.45),
        ),
      ],
    );

    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.banner),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            key: ValueKey('status-banner-${variant.name}'),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(AppRadii.banner),
              border: Border.all(color: palette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: trailing == null
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: trailing == null ? 1 : 0),
                        child: ExcludeSemantics(
                          child: Icon(
                            icon ?? palette.icon,
                            color: palette.text,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: text),
                      if (trailing != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        trailing!,
                      ],
                    ],
                  ),
                  if (action != null) ...[const SizedBox(height: 14), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
