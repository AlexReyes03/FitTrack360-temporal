import 'package:fit_track_360/app/app.dart';
import 'package:fit_track_360/design_system/components/page_header.dart';
import 'package:fit_track_360/design_system/tokens/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ds_test_harness.dart';

void main() {
  group('PageHeader', () {
    testWidgets('muestra título pageTitle, subtítulo y trailing', (
      tester,
    ) async {
      await tester.pumpWidget(
        dsHarness(
          PageHeader(
            title: 'Rutinas',
            subtitle: 'Tus planes de entrenamiento',
            trailing: const Icon(Icons.add, key: Key('trailing')),
            onBack: () {},
          ),
        ),
      );

      final title = tester.widget<Text>(find.text('Rutinas'));
      expect(title.style, AppTypography.pageTitle);
      expect(find.text('Tus planes de entrenamiento'), findsOneWidget);
      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('el título se anuncia como encabezado', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        dsHarness(PageHeader(title: 'Perfil', onBack: () {})),
      );
      expect(
        tester.getSemantics(find.text('Perfil')),
        matchesSemantics(label: 'Perfil', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('botón Volver glass de 48 dp con tooltip y semántica', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        dsHarness(PageHeader(title: 'Perfil', onBack: () {})),
      );

      final back = find.byType(GlassBackButton);
      expect(back, findsOneWidget);
      expect(tester.getSize(back), const Size(48, 48));
      expect(find.byTooltip('Volver'), findsOneWidget);
      expect(
        tester.getSemantics(back),
        matchesSemantics(
          label: 'Volver',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('onBack reemplaza la navegación por defecto', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        dsHarness(PageHeader(title: 'Perfil', onBack: () => taps++)),
      );
      await tester.tap(find.byType(GlassBackButton));
      expect(taps, 1);
    });

    testWidgets('sin onBack hace pop si hay ruta previa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: fitTrackDarkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(body: PageHeader(title: 'Detalle')),
                  ),
                ),
                child: const Text('IR'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('IR'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsOneWidget);

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsNothing);
      expect(find.text('IR'), findsOneWidget);
    });

    testWidgets('sin ruta previa usa onBackFallback', (tester) async {
      var fallbacks = 0;
      await tester.pumpWidget(
        dsHarness(
          PageHeader(title: 'Detalle', onBackFallback: () => fallbacks++),
        ),
      );
      await tester.tap(find.byType(GlassBackButton));
      await tester.pump();
      expect(fallbacks, 1);
      expect(find.text('Detalle'), findsOneWidget);
    });

    testWidgets('showBack: false oculta el botón Volver', (tester) async {
      await tester.pumpWidget(
        dsHarness(const PageHeader(title: 'Inicio', showBack: false)),
      );
      expect(find.byType(GlassBackButton), findsNothing);
      expect(find.byTooltip('Volver'), findsNothing);
    });
  });
}
