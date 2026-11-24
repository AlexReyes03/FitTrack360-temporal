import 'package:fit_track_360/design_system/tokens/app_typography.dart';
import 'package:fit_track_360/features/workouts/presentation/widgets/tracker_timer_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String elapsed,
  String rest = '01:30',
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrackerTimerSection(
            elapsedLabel: elapsed,
            isTimerRunning: true,
            restRemainingLabel: rest,
            isRestRunning: false,
            selectedRestSeconds: 90,
          ),
        ),
      ),
    ),
  );
}

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets('el cronómetro usa AppTypography.timer con cifras tabulares', (
    tester,
  ) async {
    await _pump(tester, elapsed: '00:09');

    final style = _styleOf(tester, '00:09');
    expect(style, AppTypography.timer);
    expect(style.fontSize, AppTypography.timer.fontSize);
    expect(style.fontFeatures, AppTypography.timer.fontFeatures);
    expect(style.fontFeatures, isNotEmpty);
  });

  testWidgets('el ancho del cronómetro no cambia de 00:09 a 00:10', (
    tester,
  ) async {
    await _pump(tester, elapsed: '00:09');
    final before = tester.getSize(find.text('00:09')).width;

    await _pump(tester, elapsed: '00:10');
    final after = tester.getSize(find.text('00:10')).width;

    expect(after, before);
  });

  testWidgets('el descanso usa headline con cifras tabulares', (tester) async {
    await _pump(tester, elapsed: '00:09', rest: '01:30');

    final style = _styleOf(tester, '01:30');
    expect(style.fontSize, AppTypography.headline.fontSize);
    expect(style.fontWeight, AppTypography.headline.fontWeight);
    expect(style.fontFeatures, isNotEmpty);
  });
}
