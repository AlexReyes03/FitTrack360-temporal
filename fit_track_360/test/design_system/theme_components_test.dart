import 'package:fit_track_360/app/app.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ds_test_harness.dart';

Color? _chipFill(WidgetTester tester, String label) {
  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.widgetWithText(ChoiceChip, label),
      matching: find.byType(Ink),
    ),
  );
  return (ink.decoration as ShapeDecoration?)?.color;
}

Color? _paintedTextColor(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return rich.text.style?.color;
}

void main() {
  group('ChoiceChip monocromo (hallazgo QA: «Desayuno» turquesa)', () {
    testWidgets('seleccionado: accentWhite con texto textOnAccent', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsHarness(
          Wrap(
            children: [
              ChoiceChip(
                label: const Text('Desayuno'),
                selected: true,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('Comida'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      );

      final selected = _chipFill(tester, 'Desayuno')!;
      expect(selected, AppColors.accentWhite);
      expect(isTealish(selected), isFalse);
      expect(_paintedTextColor(tester, 'Desayuno'), AppColors.textOnAccent);

      final idle = _chipFill(tester, 'Comida')!;
      expect(idle, AppColors.glassFillSoft);
      expect(isTealish(idle), isFalse);
      expect(_paintedTextColor(tester, 'Comida'), AppColors.zinc200);
    });
  });

  group('ThemeData de superficies emergentes', () {
    final theme = fitTrackDarkTheme;

    test('dialogTheme oscuro con borde glass y velo del DS', () {
      expect(theme.dialogTheme.backgroundColor, AppColors.bgMid);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.dialogTheme.barrierColor, isNotNull);
      final shape = theme.dialogTheme.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.glassBorder);
    });

    testWidgets('AlertDialog crudo hereda fondo bgMid', (tester) async {
      await tester.pumpWidget(
        dsLauncher(
          (context) => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(
              title: Text('Título'),
              content: Text('Cuerpo'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppColors.bgMid);
      expect(_paintedTextColor(tester, 'Título'), AppColors.textPrimary);
    });

    test('snackBarTheme flotante sobre bgMid con acción blanca', () {
      final snack = theme.snackBarTheme;
      expect(snack.behavior, SnackBarBehavior.floating);
      expect(snack.backgroundColor, AppColors.bgMid);
      expect(snack.actionTextColor, AppColors.accentWhite);
    });

    test('bottomSheetTheme oscuro con asa de arrastre', () {
      final sheet = theme.bottomSheetTheme;
      expect(sheet.backgroundColor, AppColors.bgMid);
      expect(sheet.modalBackgroundColor, AppColors.bgMid);
      expect(sheet.showDragHandle, isTrue);
      expect(sheet.surfaceTintColor, Colors.transparent);
    });

    test('progressIndicatorTheme en accentWhite', () {
      expect(theme.progressIndicatorTheme.color, AppColors.accentWhite);
      expect(isTealish(theme.progressIndicatorTheme.color!), isFalse);
    });

    test('textButtonTheme blanco, 48 dp y textMuted deshabilitado', () {
      final style = theme.textButtonTheme.style!;
      expect(style.foregroundColor!.resolve({}), AppColors.accentWhite);
      expect(
        style.foregroundColor!.resolve({WidgetState.disabled}),
        AppColors.textMuted,
      );
      expect(style.minimumSize!.resolve({}), const Size(48, 48));
    });

    test('switchTheme monocromo', () {
      final s = theme.switchTheme;
      const on = {WidgetState.selected};
      expect(s.trackColor!.resolve(on), AppColors.accentWhite);
      expect(s.thumbColor!.resolve(on), AppColors.textOnAccent);
      expect(s.trackColor!.resolve({}), AppColors.controlFillIdle);
      expect(s.thumbColor!.resolve({}), AppColors.accentSilver);
    });

    testWidgets('Switch y CircularProgressIndicator sin turquesa', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsHarness(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: true, onChanged: (_) {}),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
      final context = tester.element(find.byType(Switch));
      final resolved = Theme.of(context).switchTheme.trackColor!
          .resolve({WidgetState.selected})!;
      expect(isTealish(resolved), isFalse);
      expect(
        Theme.of(context).progressIndicatorTheme.color,
        AppColors.accentWhite,
      );
    });
  });
}
