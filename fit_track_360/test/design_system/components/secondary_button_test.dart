import 'package:fit_track_360/design_system/components/secondary_button.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ds_test_harness.dart';

BoxDecoration _surface(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.byKey(const ValueKey('secondary-button-surface')),
  );
  return container.decoration! as BoxDecoration;
}

Color? _labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

void main() {
  group('SecondaryButton', () {
    testWidgets('normal: pill glass de 48 dp con texto claro', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        dsHarness(SecondaryButton(label: 'Cancelar', onPressed: () => taps++)),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('secondary-button-surface')))
            .height,
        greaterThanOrEqualTo(48),
      );
      final decoration = _surface(tester);
      expect(decoration.gradient, isNotNull);
      expect(
        (decoration.border! as Border).top.color,
        AppColors.glassBorderStrong,
      );
      expect(_labelColor(tester, 'Cancelar'), AppColors.textPrimary);

      await tester.tap(find.text('Cancelar'));
      expect(taps, 1);
    });

    testWidgets('compacto: pill de 36 dp con área táctil de 48 dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsHarness(
          SecondaryButton(
            label: 'Ver todo',
            icon: Icons.chevron_right,
            size: SecondaryButtonSize.compact,
            onPressed: () {},
          ),
        ),
      );

      final surface = tester.getSize(
        find.byKey(const ValueKey('secondary-button-surface')),
      );
      expect(surface.height, lessThan(48));
      expect(surface.height, greaterThanOrEqualTo(36));
      expect(
        tester.getSize(find.byType(SecondaryButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(tester.widget<Text>(find.text('Ver todo')).style?.fontSize, 13);
    });

    testWidgets('destructivo: relleno y texto de la paleta danger', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsHarness(
          SecondaryButton(
            label: 'Eliminar',
            variant: SecondaryButtonVariant.destructive,
            onPressed: () {},
          ),
        ),
      );
      final decoration = _surface(tester);
      expect(decoration.color, AppColors.dangerFill);
      expect((decoration.border! as Border).top.color, AppColors.dangerBorder);
      expect(_labelColor(tester, 'Eliminar'), AppColors.dangerText);
    });

    testWidgets('seleccionado: relleno blanco y texto textOnAccent', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        dsHarness(
          SecondaryButton(label: 'Series', selected: true, onPressed: () {}),
        ),
      );
      expect(_surface(tester).color, AppColors.accentWhite);
      expect(_labelColor(tester, 'Series'), AppColors.textOnAccent);
      expect(
        tester.getSemantics(find.byType(SecondaryButton)),
        matchesSemantics(
          label: 'Series',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('deshabilitado: opacidad 0.55 y sin toques', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        dsHarness(const SecondaryButton(label: 'Guardar')),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(SecondaryButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.55);
      expect(
        tester.getSemantics(find.byType(SecondaryButton)),
        matchesSemantics(
          label: 'Guardar',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('isLoading: spinner, bloquea toques y conserva etiqueta', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        dsHarness(
          SecondaryButton(
            label: 'Reintentar',
            semanticLabel: 'Reintentar conexión',
            size: SecondaryButtonSize.compact,
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(SecondaryButton));
      expect(taps, 0);
      expect(find.bySemanticsLabel('Reintentar conexión'), findsOneWidget);
    });

    testWidgets('expand: ocupa todo el ancho disponible', (tester) async {
      await tester.pumpWidget(
        dsHarness(
          SizedBox(
            width: 300,
            child: SecondaryButton(
              label: 'Abrir ajustes',
              expand: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('secondary-button-surface')))
            .width,
        300,
      );
    });
  });
}
