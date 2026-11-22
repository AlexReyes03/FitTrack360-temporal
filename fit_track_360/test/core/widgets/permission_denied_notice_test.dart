import 'package:fit_track_360/core/widgets/permission_denied_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  testWidgets('renderiza titulo, mensaje e icono por defecto sin CTAs', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PermissionDeniedNotice()));

    expect(find.text('Permiso denegado'), findsOneWidget);
    expect(find.textContaining('selección manual de zona'), findsOneWidget);
    expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
  });

  testWidgets('ejecuta callbacks inyectados al tocar acciones', (tester) async {
    var primaryTaps = 0;
    var secondaryTaps = 0;

    await tester.pumpWidget(
      _host(
        PermissionDeniedNotice(
          title: 'Ubicación desactivada',
          message: 'Elige una zona manualmente para continuar.',
          icon: Icons.gps_off_rounded,
          actionLabel: 'Usar zona manual',
          onAction: () => primaryTaps++,
          secondaryActionLabel: 'Abrir ajustes',
          onSecondaryAction: () => secondaryTaps++,
        ),
      ),
    );

    expect(find.text('Ubicación desactivada'), findsOneWidget);
    expect(find.byIcon(Icons.gps_off_rounded), findsOneWidget);

    await tester.tap(find.text('Usar zona manual'));
    await tester.pumpAndSettle();
    expect(primaryTaps, 1);

    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
    expect(secondaryTaps, 1);
  });

  testWidgets('permite CTAs con callbacks nulos sin fallar', (tester) async {
    await tester.pumpWidget(
      _host(
        const PermissionDeniedNotice(
          actionLabel: 'Usar zona manual',
          secondaryActionLabel: 'Abrir ajustes',
        ),
      ),
    );

    await tester.tap(find.text('Usar zona manual'));
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
