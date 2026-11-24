import 'package:fit_track_360/features/home/presentation/widgets/dashboard_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = ['Entrenar', 'Comida', 'Foto progreso'];

/// Falla si alguna palabra de [label] se reparte en dos líneas o si el texto
/// se recorta (elipsis / maxLines excedido).
void _expectNoBrokenWords(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: '«$label» se recorta en el acceso rápido.',
  );
  var start = 0;
  for (final word in label.split(' ')) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    );
    final lines = boxes.map((box) => box.top.round()).toSet();
    expect(
      lines,
      hasLength(1),
      reason: 'La palabra «$word» se parte en ${lines.length} líneas.',
    );
    start += word.length + 1;
  }
}

Future<void> _pumpAtWidth(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Mismo padding horizontal que el scroll de Inicio (24 dp por lado).
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: DashboardQuickActions(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (device, width) in [
    ('iPhone 17 Pro', 402.0),
    ('pantalla estrecha', 320.0),
  ]) {
    testWidgets('en $device ($width dp) ninguna etiqueta parte palabras', (
      tester,
    ) async {
      await _pumpAtWidth(tester, width);

      expect(tester.takeException(), isNull);
      for (final label in _labels) {
        expect(find.text(label), findsOneWidget);
        _expectNoBrokenWords(tester, label);
      }
    });
  }

  testWidgets('usa cuadrícula si las palabras caben y filas si no', (
    tester,
  ) async {
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    double centerX(String label) => tester.getCenter(find.text(label)).dx;

    await _pumpAtWidth(tester, 600);
    expect(centerX('Entrenar'), lessThan(centerX('Comida')));
    expect(centerX('Comida'), lessThan(centerX('Foto progreso')));
    expect(top('Entrenar'), top('Comida'));

    await _pumpAtWidth(tester, 320);
    expect(top('Entrenar'), lessThan(top('Comida')));
    expect(top('Comida'), lessThan(top('Foto progreso')));
  });

  testWidgets('con texto grande de accesibilidad tampoco parte palabras', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpAtWidth(tester, 402);

    expect(tester.takeException(), isNull);
    for (final label in _labels) {
      _expectNoBrokenWords(tester, label);
    }
  });

  testWidgets('cada acceso rápido dispara su callback', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardQuickActions(
            onWorkoutTap: () => taps.add('entrenar'),
            onMealTap: () => taps.add('comida'),
            onPhotoTap: () => taps.add('foto'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Entrenar'));
    await tester.tap(find.text('Comida'));
    await tester.tap(find.text('Foto progreso'));

    expect(taps, ['entrenar', 'comida', 'foto']);
  });
}
