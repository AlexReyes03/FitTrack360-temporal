import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const TextStyle pageTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 32,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.55,
    color: AppColors.textPrimary,
  );

  static const TextStyle cta = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 16,
    color: AppColors.textOnAccent,
  );

  /// Etiqueta de boton secundario glass (p. ej. Continuar con Google).
  static const TextStyle secondaryCta = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 15.5,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  /// Texto auxiliar pequeno (separadores, notas).
  static const TextStyle caption = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 13,
    letterSpacing: 0.2,
    color: AppColors.textSecondary,
  );

  /// Glifo dentro de insignias circulares (monogramas de proveedor).
  static const TextStyle badgeGlyph = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 13,
    height: 1,
    color: AppColors.accentWhite,
  );
}
