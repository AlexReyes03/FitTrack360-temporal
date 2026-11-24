import 'package:fit_track_360/design_system/components/primary_button.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ds_test_harness.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('estado normal: toca y expone semántica de botón', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        dsHarness(PrimaryButton(label: 'Guardar', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Guardar'));
      expect(taps, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        matchesSemantics(
          label: 'Guardar',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('deshabilitado: opacidad 0.55 y semántica deshabilitada', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(dsHarness(const PrimaryButton(label: 'Enviar')));
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.55);
      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        matchesSemantics(
          label: 'Enviar',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('isLoading: spinner textOnAccent y bloquea doble toque', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        dsHarness(
          PrimaryButton(
            label: 'Crear cuenta',
            loadingLabel: 'Creando cuenta…',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, AppColors.textOnAccent);
      expect(find.text('Creando cuenta…'), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 0);

      // En carga no se ve deshabilitado: la acción sigue en curso.
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1);
      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        matchesSemantics(
          label: 'Creando cuenta…',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('isLoading sin loadingLabel conserva la etiqueta', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsHarness(
          PrimaryButton(label: 'Guardar', isLoading: true, onPressed: () {}),
        ),
      );
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('destructivo en carga: spinner blanco', (tester) async {
      await tester.pumpWidget(
        dsHarness(
          PrimaryButton(
            label: 'Eliminar cuenta',
            variant: PrimaryButtonVariant.destructive,
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, AppColors.accentWhite);
    });

    testWidgets('al terminar la carga vuelve a aceptar toques', (tester) async {
      var taps = 0;
      Widget build(bool loading) => dsHarness(
        PrimaryButton(
          label: 'Guardar',
          isLoading: loading,
          onPressed: () => taps++,
        ),
      );
      await tester.pumpWidget(build(true));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpWidget(build(false));
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 1);
    });
  });
}
