import 'package:fit_track_360/features/workouts/presentation/widgets/tracker_location_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la zona manual limita a 120 caracteres como el API', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrackerLocationSection(
              mode: TrackerLocationMode.manualZone,
              manualZoneController: controller,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a' * 150);
    expect(controller.text, hasLength(120));
  });
}
