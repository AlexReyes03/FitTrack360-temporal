import 'package:fit_track_360/features/workouts/presentation/tracker_page.dart';
import 'package:fit_track_360/features/workouts/presentation/widgets/tracker_location_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder verticalScrollable() => find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        widget.axisDirection == AxisDirection.down &&
        widget.restorationId != 'editable',
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: verticalScrollable(),
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'TrackerPage renderiza todas las secciones en preview sin errores',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrackerPage()));

      expect(find.text('Sesión activa'), findsOneWidget);
      expect(find.text('Press de banca con barra'), findsOneWidget);
      expect(find.text('Pecho'), findsOneWidget);
      expect(find.text('Ver instrucciones'), findsOneWidget);

      await scrollTo(tester, find.text('00:24:18'));
      expect(find.text('Cronómetro de sesión'), findsOneWidget);
      expect(find.text('00:24:18'), findsOneWidget);
      expect(find.text('01:30'), findsOneWidget);

      await scrollTo(tester, find.text('Anterior: 60 kg × 10'));
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Anterior: 60 kg × 10'), findsOneWidget);

      await scrollTo(tester, find.text('Agregar serie'));
      expect(find.text('Sin registro anterior'), findsOneWidget);
      expect(find.text('Agregar serie'), findsOneWidget);

      await scrollTo(tester, find.text('Notas de la sesión'));
      expect(find.text('Notas de la sesión'), findsOneWidget);

      await scrollTo(tester, find.text('Ubicación de entrenamiento'));
      expect(find.text('Ubicación de entrenamiento'), findsOneWidget);

      await scrollTo(tester, find.text('Finalizar sesión'));
      expect(find.text('Finalizar sesión'), findsOneWidget);
    },
  );

  testWidgets('TrackerPage dispara callbacks inyectados para lógica', (
    tester,
  ) async {
    var instructionsTapped = false;
    var timerToggled = false;
    int? selectedPreset;
    var setAdded = false;
    int? toggledSetIndex;
    TrackerLocationMode? selectedLocationMode;
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TrackerPage(
          onOpenInstructions: () => instructionsTapped = true,
          onToggleTimer: () => timerToggled = true,
          onSelectRestPreset: (seconds) => selectedPreset = seconds,
          onAddSet: () => setAdded = true,
          onToggleSetCompleted: (index) => toggledSetIndex = index,
          onLocationModeChanged: (mode) => selectedLocationMode = mode,
          onFinishSession: () => finished = true,
        ),
      ),
    );

    await tester.tap(find.text('Ver instrucciones'));
    expect(instructionsTapped, isTrue);

    await scrollTo(tester, find.text('Pausar'));
    await tester.tap(find.text('Pausar'));
    expect(timerToggled, isTrue);

    await scrollTo(tester, find.text('120s'));
    await tester.tap(find.text('120s'));
    expect(selectedPreset, 120);

    await scrollTo(tester, find.byTooltip('Marcar serie como pendiente'));
    await tester.tap(find.byTooltip('Marcar serie como pendiente'));
    expect(toggledSetIndex, 0);

    await scrollTo(tester, find.text('Agregar serie'));
    await tester.tap(find.text('Agregar serie'));
    expect(setAdded, isTrue);

    await scrollTo(tester, find.text('Zona manual'));
    await tester.tap(find.text('Zona manual'));
    expect(selectedLocationMode, TrackerLocationMode.manualZone);

    await scrollTo(tester, find.text('Finalizar sesión'));
    await tester.tap(find.text('Finalizar sesión'));
    expect(finished, isTrue);
  });

  testWidgets(
    'TrackerPage alterna visualmente entre GPS y Zona manual en modo preview',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrackerPage()));

      await scrollTo(tester, find.text('Zona manual'));
      expect(find.text('Usar ubicación actual'), findsOneWidget);

      await tester.tap(find.text('Zona manual'));
      await tester.pumpAndSettle();

      expect(find.text('Usar ubicación actual'), findsNothing);
      expect(
        find.text('Ej. Gimnasio Norte, Parque Central, Casa'),
        findsOneWidget,
      );
    },
  );
}
