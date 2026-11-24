import 'package:fit_track_360/design_system/components/text_link.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ds_test_harness.dart';

void main() {
  group('TextLink', () {
    testWidgets('por defecto: subrayado, textPrimary y 48 dp táctiles', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        dsHarness(TextLink(label: 'Inicia sesión', onPressed: () => taps++)),
      );
      final style = tester.widget<Text>(find.text('Inicia sesión')).style!;
      expect(style.color, AppColors.textPrimary);
      expect(style.decoration, TextDecoration.underline);
      final size = tester.getSize(find.byType(TextLink));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(find.text('Inicia sesión'));
      expect(taps, 1);
    });

    testWidgets('subtle: textSecondary sin subrayado', (tester) async {
      await tester.pumpWidget(
        dsHarness(
          TextLink(label: 'Captura manual', subtle: true, onPressed: () {}),
        ),
      );
      final style = tester.widget<Text>(find.text('Captura manual')).style!;
      expect(style.color, AppColors.textSecondary);
      expect(style.decoration, TextDecoration.none);
    });

    testWidgets('deshabilitado: textMuted', (tester) async {
      await tester.pumpWidget(dsHarness(const TextLink(label: 'Reenviar')));
      expect(
        tester.widget<Text>(find.text('Reenviar')).style!.color,
        AppColors.textMuted,
      );
    });
  });
}
