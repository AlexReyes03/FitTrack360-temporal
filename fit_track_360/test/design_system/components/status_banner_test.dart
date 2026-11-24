import 'package:fit_track_360/design_system/components/status_banner.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ds_test_harness.dart';

BoxDecoration _decoration(WidgetTester tester, StatusBannerVariant variant) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(ValueKey('status-banner-${variant.name}')),
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('StatusBanner', () {
    final cases = <StatusBannerVariant, (Color, Color, Color, IconData)>{
      StatusBannerVariant.warning: (
        AppColors.warningFill,
        AppColors.warningBorder,
        AppColors.warningText,
        Icons.info_outline_rounded,
      ),
      StatusBannerVariant.neutral: (
        AppColors.glassFillStrong,
        AppColors.glassBorderStrong,
        AppColors.zinc100,
        Icons.info_outline_rounded,
      ),
      StatusBannerVariant.success: (
        AppColors.glassFillStrong,
        AppColors.glassBorderStrong,
        AppColors.zinc100,
        Icons.check_circle_outline_rounded,
      ),
      StatusBannerVariant.danger: (
        AppColors.dangerFill,
        AppColors.dangerBorder,
        AppColors.dangerText,
        Icons.error_outline_rounded,
      ),
    };

    for (final entry in cases.entries) {
      final variant = entry.key;
      final (fill, border, text, icon) = entry.value;
      testWidgets('variante ${variant.name}: colores e ícono', (tester) async {
        await tester.pumpWidget(
          dsHarness(
            StatusBanner(variant: variant, title: 'Título', message: 'Texto'),
          ),
        );
        final decoration = _decoration(tester, variant);
        expect(decoration.color, fill);
        expect((decoration.border! as Border).top.color, border);
        expect(tester.widget<Text>(find.text('Título')).style?.color, text);
        expect(tester.widget<Text>(find.text('Texto')).style?.color, text);
        expect(find.byIcon(icon), findsOneWidget);
      });
    }

    testWidgets('éxito usa la paleta neutra con palomita (no verde)', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsHarness(
          const StatusBanner(
            variant: StatusBannerVariant.success,
            message: 'Cambios guardados',
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      final color = _decoration(tester, StatusBannerVariant.success).color!;
      expect(HSVColor.fromColor(color).saturation, 0);
    });

    testWidgets('título opcional, ícono personalizado y acciones', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        dsHarness(
          StatusBanner(
            variant: StatusBannerVariant.warning,
            message: 'Revisa tu red.',
            icon: Icons.wifi_off_rounded,
            trailing: const Text('TRAILING'),
            action: TextButton(
              onPressed: () => taps++,
              child: const Text('ACCION'),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
      expect(find.text('TRAILING'), findsOneWidget);
      await tester.tap(find.text('ACCION'));
      expect(taps, 1);
    });

    testWidgets('es live region por defecto y se puede desactivar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        dsHarness(
          const StatusBanner(
            variant: StatusBannerVariant.danger,
            message: 'No se pudo guardar',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('No se pudo guardar')),
        matchesSemantics(label: 'No se pudo guardar', isLiveRegion: true),
      );

      await tester.pumpWidget(
        dsHarness(
          const StatusBanner(
            variant: StatusBannerVariant.neutral,
            message: 'Aviso fijo',
            liveRegion: false,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Aviso fijo')),
        matchesSemantics(label: 'Aviso fijo'),
      );
      handle.dispose();
    });
  });
}
