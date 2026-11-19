import 'package:fit_track_360/features/progress/presentation/progress_page.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_checkin_card.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_range_selector.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_section_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('renderiza todas las secciones de progreso con datos mock', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ProgressPage()));

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
    expect(submitted!.weightText, '73.8');
    expect(submitted!.notesText, 'Buen descanso');
  });
}
