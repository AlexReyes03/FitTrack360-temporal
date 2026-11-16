import 'package:fit_track_360/features/nivelacion_t3/data/comidas_repositorio_falso.dart';
import 'package:fit_track_360/features/nivelacion_t3/presentation/lista_tres_estados_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra error en la primera carga y lista al reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListaTresEstadosPage(repositorio: ComidasRepositorioFalso()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudieron cargar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Avena con fruta'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });
}
