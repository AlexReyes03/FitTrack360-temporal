import 'package:fit_track_360/design_system/components/glass_surface.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: GlassSurface(child: Text('contenido'))),
    ),
  );

  Iterable<BoxDecoration> decorations(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>();

  testWidgets('la sombra exterior usa AppColors.glassShadow', (tester) async {
    await pump(tester);

    final shadowed = decorations(tester).where((d) => d.boxShadow != null);
    expect(shadowed, hasLength(1));
    expect(shadowed.single.boxShadow!.single.color, AppColors.glassShadow);
  });

  testWidgets('el brillo especular usa AppColors.glassSpecular', (
    tester,
  ) async {
    await pump(tester);

    final gradients = decorations(tester)
        .map((d) => d.gradient)
        .whereType<LinearGradient>();
    final specular = gradients.where(
      (g) => g.colors.length == 3 && g.stops == null,
    );
    expect(specular, hasLength(1));
    expect(specular.single.colors, [
      Colors.transparent,
      AppColors.glassSpecular,
      Colors.transparent,
    ]);
  });

  testWidgets('el degradado de superficie mantiene tres paradas y borde', (
    tester,
  ) async {
    await pump(tester);

    final surface = decorations(tester).where(
      (d) =>
          d.gradient is LinearGradient &&
          (d.gradient! as LinearGradient).stops != null,
    );
    expect(surface, hasLength(1));
    final gradient = surface.single.gradient! as LinearGradient;
    expect(gradient.stops, [0.0, 0.5, 1.0]);
    expect(gradient.colors, hasLength(3));
    expect((surface.single.border! as Border).top.color, AppColors.glassBorder);
  });

  testWidgets('renderiza el contenido hijo', (tester) async {
    await pump(tester);
    expect(find.text('contenido'), findsOneWidget);
  });
}
