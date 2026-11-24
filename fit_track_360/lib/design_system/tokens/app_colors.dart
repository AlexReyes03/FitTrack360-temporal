import 'package:flutter/material.dart';

/// Tokens de color del design system (solo dark, Liquid Glass white/silver).
class AppColors {
  // Fondo
  static const Color bgDeep = Color(0xFF07080C);
  static const Color bgMid = Color(0xFF0D1017);

  // Texto
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFA1A1AA);

  /// Placeholder, metadatos terciarios y micro etiquetas.
  ///
  /// Antes `#71717A` (~4.1:1 sobre [bgDeep], no cumplía WCAG AA). `#8A8A93`
  /// da ~5.9:1 sobre [bgDeep], ~5.6:1 sobre [bgMid] y ~4.5:1 sobre el relleno
  /// glass más claro (8.5 % blanco sobre [bgMid]); ver #226.
  static const Color textMuted = Color(0xFF8A8A93);
  static const Color textOnAccent = Color(0xFF090A0F);

  // Acento monocromo
  static const Color accentWhite = Color(0xFFFFFFFF);
  static const Color accentSilver = Color(0xFFD4D4D8);

  // Escala neutra del DS (titulos con gradiente, labels idle)
  static const Color zinc200 = Color(0xFFE4E4E7);
  static const Color zinc100 = Color(0xFFF4F4F5);
  static const Color gray400 = Color(0xFF9CA3AF);

  // Controles (radio/checkbox)
  static const Color controlTrack = Color(0xFF0B0D13);
  static const Color controlFillIdle = Color(0xA6090A0F);

  // Glass
  static const Color glassBorder = Color(0x1FFFFFFF);
  static const Color glassBorderStrong = Color(0x47FFFFFF);
  static const Color glassRim = Color(0x3DFFFFFF);
  static const Color glassRimFaint = Color(0x08FFFFFF);
  static const Color glassBorderPressed = Color(0x73FFFFFF);
  static const Color glassHighlight = Color(0x59FFFFFF);
  static const Color glassMarkBorder = Color(0x38FFFFFF);

  // Relleno de botones secundarios glass (gradiente superior/inferior)
  static const Color glassFillStrong = Color(0x1AFFFFFF);
  static const Color glassFillSoft = Color(0x0AFFFFFF);
  static const Color glassFillPressedStrong = Color(0x29FFFFFF);
  static const Color glassFillPressedSoft = Color(0x14FFFFFF);

  // StatusBanner
  static const Color warningFill = Color(0x24F59E0B);
  static const Color warningBorder = Color(0x66FBBF24);
  static const Color warningText = Color(0xFFFDE68A);
  static const Color dangerFill = Color(0x29EF4444);
  static const Color dangerBorder = Color(0x73F87171);
  static const Color dangerText = Color(0xFFFECACA);

  // Boton destructivo (Liquid Glass rojo)
  static const Color dangerSolidTop = Color(0xFFEF4444);
  static const Color dangerSolidMid = Color(0xFFDC2626);
  static const Color dangerSolidBottom = Color(0xFFB91C1C);
  static const Color dangerSolidPressedTop = Color(0xFFF87171);
  static const Color dangerSolidRim = Color(0x99FCA5A5);
  static const Color dangerSolidShadow = Color(0x4DEF4444);

  // Sombras y velos
  /// Sombra exterior de GlassSurface y de la barra de navegación (78 % negro).
  static const Color glassShadow = Color(0xC7000000);

  /// Velo bajo hojas modales y diálogos (60 % negro).
  static const Color scrim = Color(0x99000000);

  // Superficies glass derivadas (blanco translúcido). Sustituyen a
  // `Colors.white.withValues(alpha: x)`; ver tabla de mapeo en
  // docs/design-system.md.
  /// Tile/mosaico dentro de una tarjeta (blanco 3.5 %; absorbe 0.03–0.045).
  static const Color glassTileFill = Color(0x09FFFFFF);

  /// Bloques skeleton de carga y fondo de icono circular (blanco 6 %).
  static const Color skeletonFill = Color(0x0FFFFFFF);

  /// Bordes suaves de tiles y separadores dentro de glass (blanco 8 %).
  static const Color glassDivider = Color(0x14FFFFFF);

  /// Relleno de chip/tile seleccionado o presionado (blanco 16 %; absorbe 0.14).
  static const Color glassFillSelected = Color(0x29FFFFFF);

  /// Línea especular superior (centro del degradado, blanco 55 %).
  static const Color glassSpecular = Color(0x8CFFFFFF);

  /// Borde casi blanco de PrimaryButton y controles activos (blanco 85 %).
  static const Color ctaBorder = Color(0xD9FFFFFF);

  /// Borde de radio/checkbox inactivo (blanco 32 %).
  static const Color controlBorderIdle = Color(0x52FFFFFF);

  // Campos de texto
  /// Relleno de TextField (`rgba(7,8,12,0.72)`), usado hoy en 5 archivos.
  static const Color inputFill = Color(0xB807080C);

  /// Borde inactivo de TextField (blanco 18 %).
  static const Color inputBorder = Color(0x2EFFFFFF);

  /// Borde con foco de TextField (blanco 60 %).
  static const Color inputBorderFocused = Color(0x99FFFFFF);

  /// Borde deshabilitado de TextField (blanco 10 %).
  static const Color inputBorderDisabled = Color(0x1AFFFFFF);

  // Barra de navegación inferior
  /// Relleno base opaco de la barra glass inferior.
  static const Color navBarFill = Color(0xAD0A0C12);

  /// Degradado diagonal sobre [navBarFill] (superior, medio, inferior).
  static const Color navBarGlassTop = Color(0x18FFFFFF);
  static const Color navBarGlassMid = Color(0x08FFFFFF);
  static const Color navBarGlassBottom = Color(0x0EFFFFFF);

  // Gráficas
  /// Trazo principal de series (peso, pasos).
  static const Color chartLine = accentWhite;

  /// Líneas guía horizontales (blanco 8 %).
  static const Color chartGrid = Color(0x14FFFFFF);

  /// Degradado de área bajo la línea: arriba blanco 20 % → abajo transparente.
  static const Color chartAreaTop = Color(0x33FFFFFF);
  static const Color chartAreaBottom = Color(0x00FFFFFF);
}
