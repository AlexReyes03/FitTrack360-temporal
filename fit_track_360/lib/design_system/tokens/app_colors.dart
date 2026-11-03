import 'package:flutter/material.dart';

/// Tokens de color del design system (solo dark, Liquid Glass white/silver).
class AppColors {
  // Fondo
  static const Color bgDeep = Color(0xFF07080C);
  static const Color bgMid = Color(0xFF0D1017);

  // Texto
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);
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

  // StatusBanner
  static const Color warningFill = Color(0x24F59E0B);
  static const Color warningBorder = Color(0x66FBBF24);
  static const Color warningText = Color(0xFFFDE68A);
  static const Color dangerFill = Color(0x29EF4444);
  static const Color dangerBorder = Color(0x73F87171);
  static const Color dangerText = Color(0xFFFECACA);
}
