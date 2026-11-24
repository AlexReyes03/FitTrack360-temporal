import 'package:fit_track_360/app/app.dart';
import 'package:fit_track_360/design_system/components/page_header.dart';
import 'package:fit_track_360/design_system/templates/app_scaffold_template.dart';
import 'package:fit_track_360/design_system/templates/form_page_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(
  theme: fitTrackDarkTheme,
  home: MediaQuery(
    data: const MediaQueryData(
      size: Size(400, 800),
      padding: EdgeInsets.only(top: 40),
    ),
    child: home,
  ),
);

void main() {
  group('AppScaffoldTemplate.header', () {
    testWidgets('sin header muestra sólo el body', (tester) async {
      await tester.pumpWidget(
        _app(const AppScaffoldTemplate(body: Text('CUERPO'))),
      );
      expect(find.text('CUERPO'), findsOneWidget);
      expect(find.byType(PageHeader), findsNothing);
    });

    testWidgets('PageHeader fijo bajo el área segura y body debajo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppScaffoldTemplate(
            header: PageHeader(title: 'Rutinas', onBack: () {}),
            body: ListView(children: List.generate(40, (i) => Text('Fila $i'))),
          ),
        ),
      );

      final headerTop = tester.getTopLeft(find.byType(PageHeader)).dy;
      expect(headerTop, greaterThanOrEqualTo(40));
      final headerBottom = tester.getBottomLeft(find.byType(PageHeader)).dy;
      expect(
        tester.getTopLeft(find.text('Fila 0')).dy,
        greaterThanOrEqualTo(headerBottom),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(tester.getTopLeft(find.byType(PageHeader)).dy, headerTop);
    });
  });

  group('FormPageTemplate.header', () {
    testWidgets('acepta PageHeader sobre los campos y el CTA', (tester) async {
      await tester.pumpWidget(
        _app(
          FormPageTemplate(
            header: PageHeader(title: 'Crear cuenta', onBack: () {}),
            fields: const Text('CAMPOS'),
            primaryCta: const Text('CTA'),
          ),
        ),
      );
      final header = tester.getBottomLeft(find.byType(PageHeader)).dy;
      expect(tester.getTopLeft(find.text('CAMPOS')).dy, greaterThan(header));
      expect(find.byTooltip('Volver'), findsOneWidget);
    });
  });
}
