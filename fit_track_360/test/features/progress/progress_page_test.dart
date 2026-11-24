import 'dart:io';

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

    await tester.scrollUntilVisible(
      find.text(
        'Seguimiento personal orientativo. No sustituye valoración ni diagnóstico médico.',
      ),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(
        'Seguimiento personal orientativo. No sustituye valoración ni diagnóstico médico.',
      ),
      findsOneWidget,
    );
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

  testWidgets('sincroniza el rango cuando initialRange cambia desde el padre', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ProgressPage(initialRange: ProgressRange.d30)),
    );
    expect(find.text('Últimos 30 días'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const ProgressPage(initialRange: ProgressRange.y1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Último año'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.pumpAndSettle();
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

    await tester.ensureVisible(find.byKey(const Key('checkin-weight-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('checkin-weight-field')),
        matching: find.byType(TextField),
      ),
      '73.8',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('checkin-body-fat-field')),
        matching: find.byType(TextField),
      ),
      '18.5',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('checkin-waist-field')),
        matching: find.byType(TextField),
      ),
      '82.0',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('checkin-notes-field')),
        matching: find.byType(TextField),
      ),
      'Buen descanso',
    );

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
    expect(submitted!.bodyFatPercent, 18.5);
    expect(submitted!.waistCm, 82.0);
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

  group('validación de medidas opcionales y limpieza del check-in', () {
    Finder fieldFor(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextField),
    );

    testWidgets('rechaza % grasa corporal y cintura fuera de rango', (
      tester,
    ) async {
      ProgressCheckInDraft? submitted;
      await tester.pumpWidget(
        wrap(ProgressPage(onSubmitCheckIn: (draft) => submitted = draft)),
      );

      await tester.ensureVisible(fieldFor('checkin-weight-field'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldFor('checkin-weight-field'), '74.0');
      await tester.enterText(fieldFor('checkin-body-fat-field'), '105');
      await tester.enterText(fieldFor('checkin-waist-field'), '0');

      await tester.ensureVisible(find.text('Guardar check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar check-in'));
      await tester.pump();

      expect(submitted, isNull);
      expect(find.text('Ingresa un valor entre 0 y 100.'), findsOneWidget);
      expect(find.text('Ingresa un valor mayor a 0.'), findsOneWidget);
    });

    testWidgets('limpia el formulario solo cuando la métrica queda guardada', (
      tester,
    ) async {
      ProgressCheckInDraft? submitted;
      await tester.pumpWidget(
        wrap(
          ProgressPage(
            isSubmittingCheckIn: false,
            onSubmitCheckIn: (draft) => submitted = draft,
          ),
        ),
      );

      await tester.ensureVisible(fieldFor('checkin-weight-field'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldFor('checkin-weight-field'), '73,5');
      await tester.enterText(fieldFor('checkin-body-fat-field'), '17,2');
      await tester.enterText(fieldFor('checkin-waist-field'), '80,5');
      await tester.enterText(fieldFor('checkin-notes-field'), 'En ayunas');

      await tester.ensureVisible(find.text('Guardar check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar check-in'));
      await tester.pump();
      expect(submitted?.bodyFatPercent, 17.2);
      expect(submitted?.waistCm, 80.5);

      await tester.pumpWidget(
        wrap(const ProgressPage(isSubmittingCheckIn: true)),
      );
      await tester.pumpWidget(
        wrap(
          const ProgressPage(
            isSubmittingCheckIn: false,
            checkInFeedback: 'No se pudo completar el check-in.',
          ),
        ),
      );
      expect(
        tester
            .widget<TextField>(fieldFor('checkin-weight-field'))
            .controller!
            .text,
        '73,5',
      );

      await tester.pumpWidget(
        wrap(const ProgressPage(isSubmittingCheckIn: true)),
      );
      await tester.pumpWidget(
        wrap(
          const ProgressPage(
            isSubmittingCheckIn: false,
            checkInFeedback: 'Check-in registrado correctamente.',
            checkInSavedCount: 1,
          ),
        ),
      );

      for (final key in [
        'checkin-weight-field',
        'checkin-body-fat-field',
        'checkin-waist-field',
        'checkin-notes-field',
      ]) {
        expect(tester.widget<TextField>(fieldFor(key)).controller!.text, '');
      }
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

  group('#229 check-in y gráfica', () {
    ProgressChartData chart(int count) => ProgressChartData(
      currentWeightKg: 74.2,
      periodDeltaKg: -1.4,
      averageWeightKg: 74.9,
      points: [
        for (var i = 0; i < count; i++)
          ProgressChartPoint(label: 'P$i', weightKg: 76 - i * 0.3),
      ],
    );

    testWidgets('la foto elegida muestra miniatura y se puede quitar', (
      tester,
    ) async {
      var removed = 0;
      await tester.pumpWidget(
        wrap(
          ProgressPage(
            selectedCheckInPhotoLabel: 'selfie.jpg',
            selectedCheckInPhotoFile: File('/tmp/no-existe-229.jpg'),
            onRemoveCheckInPhoto: () => removed++,
          ),
        ),
      );
      final remove = find.byKey(const Key('checkin-remove-photo'));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkin-photo-thumbnail')), findsOneWidget);
      expect(find.text('Quitar'), findsOneWidget);
      await tester.tap(remove);
      expect(removed, 1);
    });

    testWidgets('sin foto elegida no ofrece «Quitar»', (tester) async {
      await tester.pumpWidget(wrap(ProgressPage(onRemoveCheckInPhoto: () {})));
      expect(find.byKey(const Key('checkin-remove-photo')), findsNothing);
      expect(find.byKey(const Key('checkin-photo-thumbnail')), findsNothing);
    });

    testWidgets('el aviso de éxito y el de error se distinguen', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ProgressPage(
            checkInFeedback: 'Check-in registrado correctamente.',
            checkInFeedbackTone: ProgressFeedbackTone.success,
          ),
        ),
      );
      expect(
        find.byKey(const Key('progress-feedback-success')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('progress-feedback-error')), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          const ProgressPage(
            checkInFeedback: 'Peso inválido',
            checkInFeedbackTone: ProgressFeedbackTone.error,
          ),
        ),
      );
      expect(find.byKey(const Key('progress-feedback-error')), findsOneWidget);
      expect(find.byKey(const Key('progress-feedback-success')), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('la gráfica tiene un resumen para lectores de pantalla', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrap(ProgressPage(chartData: chart(3))));

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Gráfica de evolución de peso, últimos 30 días: 3 registros '
            r'del P0 al P2\. Peso actual 74\.2 kg, variación -1\.4 kg, '
            r'promedio 74\.9 kg',
          ),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('las etiquetas del eje X quedan bajo su punto', (tester) async {
      await tester.pumpWidget(wrap(ProgressPage(chartData: chart(6))));
      await tester.pumpAndSettle();

      final plot = tester.getRect(
        find.byKey(const Key('progress-weight-chart-plot')),
      );
      final first = tester.getRect(
        find.byKey(const Key('progress-chart-x-label-0')),
      );
      final middle = tester.getRect(
        find.byKey(const Key('progress-chart-x-label-3')),
      );
      final last = tester.getRect(
        find.byKey(const Key('progress-chart-x-label-5')),
      );

      expect(first.left, closeTo(plot.left, 0.5));
      expect(last.right, closeTo(plot.right, 0.5));
      expect(middle.center.dx, closeTo(plot.left + plot.width * 3 / 5, 0.5));
    });
  });
}
