import 'package:fit_track_360/design_system/components/app_snack_bar.dart';
import 'package:fit_track_360/design_system/components/glass_bottom_sheet.dart';
import 'package:fit_track_360/design_system/components/glass_dialog.dart';
import 'package:fit_track_360/design_system/components/glass_surface.dart';
import 'package:fit_track_360/design_system/components/primary_button.dart';
import 'package:fit_track_360/design_system/components/secondary_button.dart';
import 'package:fit_track_360/design_system/components/status_banner.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ds_test_harness.dart';

void main() {
  group('GlassDialog', () {
    testWidgets('showGlassDialog pinta GlassSurface, no AlertDialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsLauncher(
          (context) => showGlassDialog<void>(
            context: context,
            builder: (_) => const GlassDialog(
              title: 'Aviso de privacidad',
              message: 'Texto del aviso',
              content: Text('CONTENIDO'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.text('Aviso de privacidad'), findsOneWidget);
      expect(find.text('Texto del aviso'), findsOneWidget);
      expect(find.text('CONTENIDO'), findsOneWidget);
      final barrier = tester.widgetList<ModalBarrier>(
        find.byType(ModalBarrier),
      );
      expect(barrier.map((b) => b.color), contains(glassBarrierColor));
    });

    testWidgets('confirmación destructiva: botón rojo y devuelve true', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        dsLauncher((context) async {
          result = await showGlassConfirmDialog(
            context: context,
            title: '¿Eliminar sesión?',
            message: 'No podrás recuperarla.',
            confirmLabel: 'Eliminar',
            destructive: true,
          );
        }),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      final confirm = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Eliminar'),
      );
      expect(confirm.variant, PrimaryButtonVariant.destructive);
      expect(find.widgetWithText(SecondaryButton, 'Cancelar'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(GlassDialog), findsNothing);
    });

    testWidgets('confirmación: Cancelar o tocar el velo devuelve false', (
      tester,
    ) async {
      final results = <bool>[];
      await tester.pumpWidget(
        dsLauncher((context) async {
          results.add(
            await showGlassConfirmDialog(
              context: context,
              title: '¿Salir?',
              confirmLabel: 'Salir',
            ),
          );
        }),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).variant,
        PrimaryButtonVariant.primary,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(results, [false, false]);
    });
  });

  group('showGlassBottomSheet', () {
    testWidgets('hoja oscura con título y opciones que devuelven valor', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        dsLauncher((context) async {
          picked = await showGlassBottomSheet<String>(
            context: context,
            title: 'Agregar foto',
            builder: (sheetContext) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassSheetAction(
                  icon: Icons.photo_camera_outlined,
                  label: 'Cámara',
                  onTap: () => Navigator.pop(sheetContext, 'camera'),
                ),
                GlassSheetAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Galería',
                  onTap: () => Navigator.pop(sheetContext, 'gallery'),
                ),
              ],
            ),
          );
        }),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, AppColors.bgMid);
      expect(sheet.showDragHandle, isTrue);
      expect(find.text('Agregar foto'), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(GlassSheetAction, 'Cámara')).height,
        greaterThanOrEqualTo(56),
      );

      await tester.tap(find.text('Galería'));
      await tester.pumpAndSettle();
      expect(picked, 'gallery');
    });

    testWidgets('opción destructiva en dangerText', (tester) async {
      await tester.pumpWidget(
        dsLauncher(
          (context) => showGlassBottomSheet<void>(
            context: context,
            builder: (_) => GlassSheetAction(
              label: 'Eliminar foto',
              icon: Icons.delete_outline,
              destructive: true,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Eliminar foto')).style?.color,
        AppColors.dangerText,
      );
    });
  });

  group('showAppSnackBar', () {
    testWidgets('flotante, fondo bgMid y reemplaza al anterior', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsLauncher((context) {
          showAppSnackBar(context, message: 'Primero');
          showAppSnackBar(
            context,
            message: 'Guardado',
            variant: StatusBannerVariant.success,
          );
        }),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      expect(find.text('Guardado'), findsOneWidget);
      expect(find.text('Primero'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppColors.bgMid);
      final theme = Theme.of(tester.element(find.byType(SnackBar)));
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });

    testWidgets('variante danger con acción', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        dsLauncher(
          (context) => showAppSnackBar(
            context,
            message: 'No se pudo agregar el alimento',
            variant: StatusBannerVariant.danger,
            actionLabel: 'Reintentar',
            onAction: () => retries++,
          ),
        ),
      );
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.text('No se pudo agregar el alimento'))
            .style
            ?.color,
        AppColors.dangerText,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });
  });
}
