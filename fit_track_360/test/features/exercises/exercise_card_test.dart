import 'package:fit_track_360/features/exercises/data/exercise.dart';
import 'package:fit_track_360/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:fit_track_360/features/exercises/presentation/widgets/exercise_media_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/exercise_test_support.dart';

Future<void> pumpCard(
  WidgetTester tester, {
  required Exercise exercise,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExerciseCard(exercise: exercise, onTap: onTap ?? () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('usa nameEs como título y el nombre original como subtítulo', (
    tester,
  ) async {
    await pumpCard(
      tester,
      exercise: Exercise.fromJson(exerciseJson(nameEs: 'Abdominal 3/4')),
    );

    final title = tester.getTopLeft(find.text('Abdominal 3/4'));
    final subtitle = tester.getTopLeft(find.text('3/4 sit-up'));
    expect(title.dy, lessThan(subtitle.dy));
    final titleStyle = tester.widget<Text>(find.text('Abdominal 3/4')).style;
    expect(titleStyle?.fontWeight, FontWeight.w700);
  });

  testWidgets('sin nameEs muestra el nombre original una sola vez', (
    tester,
  ) async {
    await pumpCard(tester, exercise: Exercise.fromJson(exerciseJson()));

    expect(find.text('3/4 sit-up'), findsOneWidget);
  });

  testWidgets('es un botón accesible con InkWell y responde al toque', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpCard(
      tester,
      exercise: Exercise.fromJson(exerciseJson(nameEs: 'Abdominal 3/4')),
      onTap: () => taps++,
    );

    expect(
      find.descendant(
        of: find.byType(ExerciseCard),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ExerciseCard),
        matching: find.byType(GestureDetector).hitTestable(),
      ),
      findsWidgets,
    );
    expect(
      tester.getSemantics(find.byType(ExerciseCard)),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Abdominal 3/4, Cintura, Peso corporal',
      ),
    );

    await tester.tap(find.byType(ExerciseCard));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('la miniatura decodifica a su tamaño con cacheWidth', (
    tester,
  ) async {
    await pumpCard(tester, exercise: Exercise.fromJson(exerciseJson()));

    final image = tester.widget<Image>(find.byKey(ExerciseMediaView.imageKey));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    final dpr = tester.view.devicePixelRatio;
    expect((provider as ResizeImage).width, (72 * dpr).round());
  });

  testWidgets('muestra un skeleton mientras carga la imagen', (tester) async {
    await pumpCard(tester, exercise: Exercise.fromJson(exerciseJson()));

    final image = tester.widget<Image>(find.byKey(ExerciseMediaView.imageKey));
    expect(image.loadingBuilder, isNotNull);

    final context = tester.element(find.byKey(ExerciseMediaView.imageKey));
    const child = SizedBox(key: Key('decoded'));
    final loading = image.loadingBuilder!(
      context,
      child,
      const ImageChunkEvent(cumulativeBytesLoaded: 10, expectedTotalBytes: 100),
    );
    final done = image.loadingBuilder!(context, child, null);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SizedBox(width: 72, height: 72, child: loading),
            SizedBox(width: 72, height: 72, child: done),
          ],
        ),
      ),
    );

    expect(find.byKey(ExerciseMediaView.skeletonKey), findsOneWidget);
    expect(find.byKey(const Key('decoded')), findsOneWidget);
  });
}
