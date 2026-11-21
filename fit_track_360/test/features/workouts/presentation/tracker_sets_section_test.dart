import 'package:fit_track_360/features/workouts/presentation/widgets/tracker_sets_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra el texto de error de la serie, no solo el borde', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrackerSetsSection(
              sets: [
                TrackerSetItem(
                  id: 'a',
                  order: 1,
                  weightText: 'Infinity',
                  repsText: '10',
                  hasWeightError: true,
                  errorText: 'Peso: de 0 a 1000 kg',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Peso: de 0 a 1000 kg'), findsOneWidget);
  });
}
