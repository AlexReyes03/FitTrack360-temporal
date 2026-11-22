import 'package:fit_track_360/features/progress/presentation/progress_page.dart';
import 'package:fit_track_360/features/progress/presentation/state/progress_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('renderiza todas las secciones de progreso con datos mock', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ProgressPage(usePreviewData: true)));

    expect(find.text('Progreso'), findsOneWidget);
    expect(find.text('7d'), findsOneWidget);
    expect(find.text('30d'), findsWidgets);
    expect(find.text('90d'), findsOneWidget);
    expect(find.text('1y'), findsOneWidget);
    expect(find.text('Evolución de peso'), findsOneWidget);
    expect(find.text('Nuevo check-in'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Historial de registros'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Historial de registros'), findsOneWidget);
    expect(find.text('-0.4 kg vs sem. ant.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Comparación de fotos'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Comparación de fotos'), findsOneWidget);
    expect(find.text('Inicial'), findsOneWidget);
    expect(find.text('Actual'), findsWidgets);
  });

  testWidgets('cambiar rango actualiza la vista y dispara onRangeChanged', (
    tester,
  ) async {
    ProgressRange? selected;

    await tester.pumpWidget(
      wrap(ProgressPage(onRangeChanged: (range) => selected = range)),
    );

    await tester.tap(find.text('90d'));
    await tester.pumpAndSettle();

    expect(selected, ProgressRange.d90);
    expect(find.text('Últimos 90 días'), findsOneWidget);
  });

  testWidgets('renderiza estados loading, empty y error con reintentar', (
    tester,
  ) async {
    var retriedHistory = 0;

    await tester.pumpWidget(
      wrap(
        ProgressPage(
          chartStatus: ProgressSectionStatus.loading,
          historyStatus: ProgressSectionStatus.error,
          comparisonStatus: ProgressSectionStatus.empty,
          onRetryHistory: () => retriedHistory++,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Reintentar'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('No se pudo cargar el historial de progreso.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(retriedHistory, 1);

    await tester.scrollUntilVisible(
      find.text('Sin fotos para comparar'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sin fotos para comparar'), findsOneWidget);
  });

  testWidgets('valida y dispara callbacks de check-in y foto', (tester) async {
    var photoTapped = 0;
    ProgressCheckInDraft? submitted;

    await tester.pumpWidget(
      wrap(
        ProgressPage(
          onSelectCheckInPhoto: () => photoTapped++,
          onSubmitCheckIn: (draft) => submitted = draft,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Guardar check-in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar check-in'));
    await tester.pump();
    expect(
      find.text('Ingresa tu peso en kg para guardar el check-in.'),
      findsOneWidget,
    );
    expect(submitted, isNull);

    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '73.8');
    await tester.enterText(find.byType(TextField).at(1), 'Buen descanso');

    await tester.ensureVisible(find.text('Agregar foto de progreso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar foto de progreso'));
    await tester.pump();
    expect(photoTapped, 1);

    await tester.ensureVisible(find.text('Guardar check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar check-in'));
    await tester.pump();
    expect(submitted, isNotNull);
    expect(submitted!.weightKg, 73.8);
    expect(submitted!.notesText, 'Buen descanso');
  });

  testWidgets('por defecto no muestra datos de maqueta', (tester) async {
    await tester.pumpWidget(wrap(const ProgressPage()));

    expect(find.text('74.2 kg'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Comparación de fotos'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('-0.4 kg vs sem. ant.'), findsNothing);
    expect(find.text('77.4 kg'), findsNothing);
    expect(find.text('Frente · Inicio'), findsNothing);
  });

  group('validación de peso del check-in', () {
    Future<ProgressCheckInDraft?> submitWeight(
      WidgetTester tester,
      String weight,
    ) async {
      ProgressCheckInDraft? submitted;
      await tester.pumpWidget(
        wrap(ProgressPage(onSubmitCheckIn: (draft) => submitted = draft)),
      );
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, weight);
      await tester.ensureVisible(find.text('Guardar check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar check-in'));
      await tester.pump();
      return submitted;
    }

    for (final invalid in ['abc', '0', '-5', '12', '650', '7,4,2']) {
      testWidgets('rechaza "$invalid" y muestra el error en el formulario', (
        tester,
      ) async {
        final submitted = await submitWeight(tester, invalid);

        expect(submitted, isNull);
        expect(
          find.text('Ingresa un peso válido entre 20 y 500 kg.'),
          findsOneWidget,
        );
      });
    }

    testWidgets('acepta coma decimal y no promete guardar el peso', (
      tester,
    ) async {
      final submitted = await submitWeight(tester, '73,8');

      expect(submitted, isNotNull);
      expect(submitted!.weightKg, 73.8);
      expect(find.textContaining('listo para guardar'), findsNothing);
    });
  });

  testWidgets('muestra en el formulario el mensaje del check-in', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ProgressPage(checkInFeedback: 'Tu peso aún no se guarda (#122).'),
      ),
    );
    await tester.ensureVisible(find.text('Guardar check-in'));
    await tester.pumpAndSettle();

    expect(find.text('Tu peso aún no se guarda (#122).'), findsOneWidget);
  });
}
