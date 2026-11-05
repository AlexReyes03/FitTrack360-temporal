import 'package:flutter/material.dart';

/// Variantes del arte de marca FitTrack360.
///
/// [mark] y [compact] usan el emblema cuadrado; [full] usa el lockup completo
/// (emblema mas tipografia) sin fondo, pensado para superficies del DS.
enum AppLogoVariant { mark, full, compact }

/// Logo de marca del design system.
///
/// Es el unico widget que resuelve las rutas de `assets/brand/`; las pantallas
/// no deben usar `Image.asset` con la marca directamente.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.variant = AppLogoVariant.mark,
    this.height = defaultHeight,
    this.semanticLabel = 'FitTrack360',
  });

  /// Altura por defecto para usos compactos (headers, pills).
  static const double defaultHeight = 40;

  /// Altura sugerida para la cabecera de login.
  static const double loginHeight = 132;

  /// Altura sugerida para el splash in-app.
  static const double splashHeight = 208;

  static const String _markAsset = 'assets/brand/favicon.png';
  static const String _fullAsset = 'assets/brand/logo-no-bg.png';

  final AppLogoVariant variant;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final asset = variant == AppLogoVariant.full ? _fullAsset : _markAsset;

    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: semanticLabel,
    );
  }
}
