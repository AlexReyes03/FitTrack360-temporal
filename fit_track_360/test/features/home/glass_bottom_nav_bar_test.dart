import 'package:fit_track_360/app/app.dart';
import 'package:fit_track_360/design_system/tokens/app_colors.dart';
import 'package:fit_track_360/features/home/presentation/widgets/glass_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = [
  GlassNavDestination(label: 'Inicio', icon: Icons.home_outlined),
  GlassNavDestination(label: 'Entrenos', icon: Icons.fitness_center_outlined),
  GlassNavDestination(label: 'Comidas', icon: Icons.restaurant_outlined),
  GlassNavDestination(
    label: 'Ejercicios',
    icon: Icons.sports_gymnastics_outlined,
  ),
  GlassNavDestination(label: 'Progreso', icon: Icons.photo_camera_outlined),
  GlassNavDestination(label: 'Perfil', icon: Icons.person_outline_rounded),
];

Widget _host({
  double textScale = 1,
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
}) {
  return MaterialApp(
    theme: fitTrackDarkTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          backgroundColor: AppColors.bgDeep,
          body: const SizedBox.expand(),
          bottomNavigationBar: GlassBottomNavBar(
            destinations: _destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

double _labelHeight(WidgetTester tester, String label) {
  return tester.getSize(find.text(label)).height;
}

void main() {
  testWidgets('las etiquetas no usan FittedBox y miden al menos 11dp', (
    tester,
  ) async {
    _setScreen(tester, const Size(390, 800));
    await tester.pumpWidget(_host());

    expect(
      find.descendant(
        of: find.byType(GlassBottomNavBar),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
    );
    for (final d in _destinations) {
      final text = tester.widget<Text>(find.text(d.label));
      expect(text.style!.fontSize, greaterThanOrEqualTo(11), reason: d.label);
    }
  });

  testWidgets('las etiquetas crecen al subir el tamaño de texto', (
    tester,
  ) async {
    _setScreen(tester, const Size(760, 800));
    await tester.pumpWidget(_host());
    final normal = _labelHeight(tester, 'Inicio');

    await tester.pumpWidget(_host(textScale: 1.3));
    await tester.pump();
    final large = _labelHeight(tester, 'Inicio');

    expect(large, greaterThan(normal));
  });

  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets('no desborda a 320dp con escala de texto $scale', (
      tester,
    ) async {
      _setScreen(tester, const Size(320, 640));
      await tester.pumpWidget(_host(textScale: scale));
      await tester.pump();

      expect(tester.takeException(), isNull);
      for (final d in _destinations) {
        expect(find.text(d.label), findsOneWidget);
      }
    });
  }

  testWidgets('cada destino se anuncia una vez, como botón y su estado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    _setScreen(tester, const Size(390, 800));
    await tester.pumpWidget(_host(selectedIndex: 2));

    for (var i = 0; i < _destinations.length; i++) {
      final label = _destinations[i].label;
      final finder = find.bySemanticsLabel(RegExp(label));
      expect(finder, findsOneWidget, reason: label);
      final node = tester.getSemantics(finder);
      // Sin lectura doble: la etiqueta no se repite ("Inicio\nInicio").
      expect(node.label, label);
      expect(node.flagsCollection.isButton, isTrue, reason: label);
      expect(
        node.getSemanticsData().flagsCollection.isSelected.toBoolOrNull(),
        i == 2,
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('tocar un destino notifica su índice', (tester) async {
    _setScreen(tester, const Size(320, 640));
    int? tapped;
    await tester.pumpWidget(_host(onSelected: (i) => tapped = i));

    await tester.tap(find.text('Ejercicios'));
    await tester.pump();
    expect(tapped, 3);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('cumple guías de área táctil y contraste a ${width}dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      _setScreen(tester, Size(width, 800));
      await tester.pumpWidget(_host());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
