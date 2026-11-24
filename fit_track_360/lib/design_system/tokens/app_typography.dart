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

  /// Título de pantallas de autenticación (login, registro, recuperar).
  static const TextStyle authTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 28,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// Cifra protagonista de una tarjeta de métrica (pasos, kcal).
  static const TextStyle metricValue = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 28,
    letterSpacing: -0.6,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  /// Encabezado de bloque destacado (saludo, nombre de perfil, ejercicio).
  static const TextStyle headline = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 22,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// Título de sección/tarjeta principal de una pantalla.
  static const TextStyle sectionTitle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  /// Título de un elemento dentro de una tarjeta (fila, tile, ítem de lista).
  static const TextStyle cardTitle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  /// Etiqueta de campo o dato secundario con peso (TextField label).
  static const TextStyle label = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  /// Metadatos: fechas, unidades, subtítulos cortos.
  static const TextStyle meta = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  /// Micro texto: overlines en mayúsculas, contadores, leyendas de gráfica.
  static const TextStyle micro = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 0.6,
    color: AppColors.textMuted,
  );

  /// Etiqueta de destino en la barra de navegación inferior (inactivo).
  static const TextStyle navLabel = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 10.5,
    letterSpacing: -0.2,
    color: AppColors.textSecondary,
  );

  /// Etiqueta de destino seleccionado en la barra inferior.
  static const TextStyle navLabelSelected = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 10.5,
    letterSpacing: -0.2,
    color: AppColors.accentWhite,
  );

  /// Título de StatusBanner/OfflineBanner. Color neutro; las variantes
  /// warning/danger hacen `copyWith(color: AppColors.warningText)`.
  static const TextStyle bannerTitle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: AppColors.zinc100,
  );

  /// Cuerpo de StatusBanner/OfflineBanner.
  static const TextStyle bannerBody = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.4,
    color: AppColors.zinc100,
  );

  /// Cronómetro de sesión: cifras tabulares para que no "bailen".
  static const TextStyle timer = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 42,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
