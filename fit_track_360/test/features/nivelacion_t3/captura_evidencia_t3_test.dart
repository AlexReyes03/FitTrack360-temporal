import 'dart:io';
import 'dart:ui' as ui;

import 'package:fit_track_360/features/nivelacion_t3/data/comidas_repositorio_falso.dart';
import 'package:fit_track_360/features/nivelacion_t3/presentation/lista_tres_estados_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _outDir =
    r'C:\Users\anton\10 cuatri\Carsi\FitTrack360-temporal\docs\evidencia-t3';

Future<void> _savePng(WidgetTester tester, String fileName) async {
  final boundary = tester.renderObject(
    find.byKey(const ValueKey('t3-capture')),
  ) as RenderRepaintBoundary;

  // toImage usa el motor real; debe ir fuera del fake-async del test.
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir${Platform.pathSeparator}$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    // ignore: avoid_print
    print('WROTE ${file.path} bytes=${file.lengthSync()}');
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('genera evidencias PNG de cargando, error y exito', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = ComidasRepositorioFalso();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('t3-capture'),
          child: ListaTresEstadosPage(repositorio: repo),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _savePng(tester, '01-cargando.png');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Reintentar'), findsOneWidget);
    await _savePng(tester, '02-error-reintentar.png');

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Avena con fruta'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
    await _savePng(tester, '03-lista-exito.png');
  });
}
