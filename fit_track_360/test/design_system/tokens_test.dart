import 'dart:math' as math;

import 'package:fit_track_360/design_system/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Luminancia relativa WCAG 2.x de un color sRGB opaco.
double _relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Razón de contraste WCAG entre dos colores opacos.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Contraste WCAG', () {
    test('la función de contraste reproduce valores de referencia', () {
      expect(
        contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21, 0.01),
      );
      // Valor anterior de textMuted: ~4.1:1 sobre bgDeep (no cumplía AA).
      expect(
        contrastRatio(const Color(0xFF71717A), AppColors.bgDeep),
        lessThan(4.5),
      );
    });

    test('textMuted cumple AA (>= 4.5:1) sobre bgDeep y bgMid', () {
      expect(
        contrastRatio(AppColors.textMuted, AppColors.bgDeep),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(AppColors.textMuted, AppColors.bgMid),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('textMuted cumple AA sobre el relleno glass más claro (8.5 %)', () {
      final glassOverMid = Color.alphaBlend(
        const Color(0xFFFFFFFF).withValues(alpha: 0.085),
        AppColors.bgMid,
      );
      expect(
        contrastRatio(AppColors.textMuted, glassOverMid),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('textMuted sigue siendo más tenue que textSecondary', () {
      expect(
        _relativeLuminance(AppColors.textMuted),
        lessThan(_relativeLuminance(AppColors.textSecondary)),
      );
    });

    test('textSecondary y textPrimary cumplen AA sobre bgDeep y bgMid', () {
      for (final fg in [AppColors.textPrimary, AppColors.textSecondary]) {
        for (final bg in [AppColors.bgDeep, AppColors.bgMid]) {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));
        }
      }
    });
  });

  group('AppColors', () {
    test('conserva los tokens existentes', () {
      expect(AppColors.bgDeep, const Color(0xFF07080C));
      expect(AppColors.bgMid, const Color(0xFF0D1017));
      expect(AppColors.textPrimary, const Color(0xFFF8FAFC));
      expect(AppColors.textSecondary, const Color(0xFFA1A1AA));
      expect(AppColors.textOnAccent, const Color(0xFF090A0F));
      expect(AppColors.accentWhite, const Color(0xFFFFFFFF));
      expect(AppColors.zinc100, const Color(0xFFF4F4F5));
      expect(AppColors.zinc200, const Color(0xFFE4E4E7));
      expect(AppColors.glassBorder, const Color(0x1FFFFFFF));
      expect(AppColors.warningFill, const Color(0x24F59E0B));
      expect(AppColors.warningBorder, const Color(0x66FBBF24));
      expect(AppColors.warningText, const Color(0xFFFDE68A));
    });

    test('inputFill coincide con el literal usado hoy en los campos', () {
      // Literal repetido en ds_text_field, tracker_page, tracker_sets_section,
      // tracker_location_section y exercise_filters.
      expect(AppColors.inputFill, const Color(0xB807080C));
    });

    test('navBarFill coincide con el relleno actual de la barra inferior', () {
      expect(AppColors.navBarFill, const Color(0xAD0A0C12));
      expect(AppColors.navBarGlassTop, const Color(0x18FFFFFF));
      expect(AppColors.navBarGlassMid, const Color(0x08FFFFFF));
      expect(AppColors.navBarGlassBottom, const Color(0x0EFFFFFF));
    });

    test('glassShadow coincide con la sombra de GlassSurface y la barra', () {
      expect(AppColors.glassShadow, const Color(0xC7000000));
    });

    test('rellenos blancos translúcidos tienen el alfa documentado', () {
      expect(AppColors.glassTileFill.a, closeTo(0.035, 0.003));
      expect(AppColors.skeletonFill.a, closeTo(0.06, 0.003));
      expect(AppColors.glassDivider.a, closeTo(0.08, 0.003));
      expect(AppColors.glassFillSelected.a, closeTo(0.16, 0.003));
      expect(AppColors.inputBorder.a, closeTo(0.18, 0.003));
      expect(AppColors.inputBorderFocused.a, closeTo(0.6, 0.003));
      expect(AppColors.inputBorderDisabled.a, closeTo(0.10, 0.003));
      expect(AppColors.controlBorderIdle.a, closeTo(0.32, 0.003));
      expect(AppColors.glassSpecular.a, closeTo(0.55, 0.003));
      expect(AppColors.ctaBorder.a, closeTo(0.85, 0.003));
      for (final c in [
        AppColors.glassTileFill,
        AppColors.skeletonFill,
        AppColors.glassDivider,
        AppColors.glassFillSelected,
        AppColors.inputBorder,
        AppColors.inputBorderFocused,
        AppColors.inputBorderDisabled,
        AppColors.controlBorderIdle,
        AppColors.glassSpecular,
        AppColors.ctaBorder,
      ]) {
        expect(c.withValues(alpha: 1), const Color(0xFFFFFFFF));
      }
    });

    test('scrim es negro translúcido', () {
      expect(AppColors.scrim, const Color(0x99000000));
    });

    test('tokens de gráfica', () {
      expect(AppColors.chartLine, AppColors.accentWhite);
      expect(AppColors.chartGrid.a, closeTo(0.08, 0.003));
      expect(AppColors.chartAreaTop.a, closeTo(0.20, 0.003));
      expect(AppColors.chartAreaBottom.a, 0);
    });
  });

  group('AppSpacing', () {
    test('escala completa y ordenada', () {
      expect(AppSpacing.hairline, 2);
      expect(AppSpacing.xxs, 4);
      expect(AppSpacing.xs, 8);
      expect(AppSpacing.sm, 12);
      expect(AppSpacing.base, 16);
      expect(AppSpacing.md, 24);
      expect(AppSpacing.lg, 32);
      expect(AppSpacing.contentMaxWidth, 760);
      const scale = [
        AppSpacing.hairline,
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.lg,
      ];
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('alias semánticos para tarjetas y secciones', () {
      expect(AppSpacing.cardPadding, AppSpacing.md);
      expect(AppSpacing.sectionGap, AppSpacing.base);
    });
  });

  group('AppRadii', () {
    test('conserva los radios existentes', () {
      expect(AppRadii.card, 24);
      expect(AppRadii.inner, 18);
      expect(AppRadii.option, 14);
      expect(AppRadii.nps, 12);
      expect(AppRadii.input, 14);
      expect(AppRadii.badge, 8);
      expect(AppRadii.checkbox, 6.4);
      expect(AppRadii.pill, 999);
      expect(AppRadii.banner, 14);
    });
  });

  group('AppTypography', () {
    void expectStyle(
      TextStyle style, {
      required double size,
      required FontWeight weight,
      Color? color,
    }) {
      expect(style.fontSize, size);
      expect(style.fontWeight, weight);
      if (color != null) expect(style.color, color);
    }

    test('conserva los roles existentes', () {
      expectStyle(AppTypography.pageTitle, size: 32, weight: FontWeight.w800);
      expectStyle(AppTypography.body, size: 14, weight: FontWeight.w400);
      expectStyle(AppTypography.cta, size: 16, weight: FontWeight.w800);
      expectStyle(
        AppTypography.secondaryCta,
        size: 15.5,
        weight: FontWeight.w700,
      );
      expectStyle(AppTypography.caption, size: 13, weight: FontWeight.w500);
      expectStyle(AppTypography.badgeGlyph, size: 13, weight: FontWeight.w800);
    });

    test('roles nuevos derivados de los literales medidos', () {
      expectStyle(
        AppTypography.authTitle,
        size: 28,
        weight: FontWeight.w800,
        color: AppColors.textPrimary,
      );
      expectStyle(
        AppTypography.metricValue,
        size: 28,
        weight: FontWeight.w800,
        color: AppColors.textPrimary,
      );
      expectStyle(
        AppTypography.headline,
        size: 22,
        weight: FontWeight.w800,
        color: AppColors.textPrimary,
      );
      expectStyle(
        AppTypography.sectionTitle,
        size: 16,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
      expectStyle(
        AppTypography.cardTitle,
        size: 15,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
      expectStyle(
        AppTypography.label,
        size: 14,
        weight: FontWeight.w600,
        color: AppColors.textSecondary,
      );
      expectStyle(
        AppTypography.meta,
        size: 12,
        weight: FontWeight.w600,
        color: AppColors.textSecondary,
      );
      expectStyle(
        AppTypography.micro,
        size: 11,
        weight: FontWeight.w600,
        color: AppColors.textMuted,
      );
      expectStyle(AppTypography.navLabel, size: 10.5, weight: FontWeight.w500);
      expectStyle(
        AppTypography.navLabelSelected,
        size: 10.5,
        weight: FontWeight.w700,
      );
      expectStyle(
        AppTypography.bannerTitle,
        size: 15,
        weight: FontWeight.w700,
        color: AppColors.zinc100,
      );
      expectStyle(
        AppTypography.bannerBody,
        size: 13,
        weight: FontWeight.w400,
        color: AppColors.zinc100,
      );
      expectStyle(
        AppTypography.timer,
        size: 42,
        weight: FontWeight.w800,
        color: AppColors.textPrimary,
      );
    });

    test('timer usa cifras tabulares para no "bailar" al contar', () {
      expect(
        AppTypography.timer.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('la jerarquía de tamaños es estrictamente descendente', () {
      final sizes = [
        AppTypography.pageTitle.fontSize!,
        AppTypography.authTitle.fontSize!,
        AppTypography.headline.fontSize!,
        AppTypography.sectionTitle.fontSize!,
        AppTypography.cardTitle.fontSize!,
        AppTypography.label.fontSize!,
        AppTypography.caption.fontSize!,
        AppTypography.meta.fontSize!,
        AppTypography.micro.fontSize!,
        AppTypography.navLabel.fontSize!,
      ];
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], lessThan(sizes[i - 1]));
      }
    });
  });
}
