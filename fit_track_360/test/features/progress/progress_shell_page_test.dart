import 'package:fit_track_360/features/progress/domain/body_metric.dart';
import 'package:fit_track_360/features/progress/presentation/progress_shell_page.dart';
import 'package:fit_track_360/features/progress/presentation/progress_view_model.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_history_card.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_photo_comparison_card.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_range_selector.dart';
import 'package:fit_track_360/features/progress/presentation/widgets/progress_weight_chart_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'support/fake_progress_metrics_repository.dart';
import 'support/fake_progress_photos_repository.dart';

class _RangeAwareMetricsRepository extends FakeProgressMetricsRepository {
  _RangeAwareMetricsRepository({
    required this.seriesByFrom,
    required this.historyByFrom,
  });

  final Map<String, ProgressSeries> seriesByFrom;
  final Map<String, List<BodyMetric>> historyByFrom;

  @override
  Future<ProgressSeries> getSeries({String? from, String? to}) async {
    seriesRequests.add((from: from, to: to));
    return seriesByFrom[from] ?? emptyProgressSeries();
  }

  @override
  Future<List<BodyMetric>> listHistory({String? from, String? to}) async {
    historyRequests.add((from: from, to: to));
    return historyByFrom[from] ?? const [];
  }
}

void main() {
  Finder fieldFor(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );

  Future<void> tapSelectPhoto(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Agregar foto de progreso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar foto de progreso'));
    await tester.pumpAndSettle();
  }

  testWidgets('si el selector falla avisa al usuario sin romper', (
    tester,
  ) async {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgressShellPage(
          viewModel: vm,
          pickCheckInPhoto: () async =>
              throw PlatformException(code: 'photo_access_denied'),
        ),
      ),
    );
    await tapSelectPhoto(tester);

    expect(
      find.text('No se pudo abrir la galería. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(vm.selectedCheckInPhotoLabel, isNull);
  });

  testWidgets('la foto elegida queda adjunta al check-in', (tester) async {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgressShellPage(
          viewModel: vm,
          pickCheckInPhoto: () async => XFile('/tmp/selfie.jpg'),
        ),
      ),
    );
    await tapSelectPhoto(tester);

    expect(vm.selectedCheckInPhotoLabel, 'selfie.jpg');
    expect(find.text('Foto adjunta al check-in'), findsOneWidget);
  });

  testWidgets('check-in sin foto muestra en el formulario que no se guarda', (
    tester,
  ) async {
    final repo = FakeProgressPhotosRepository();
    final vm = ProgressViewModel(photos: repo);
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ProgressShellPage(viewModel: vm)),
    );
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '74.2');
    await tester.ensureVisible(find.text('Guardar check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar check-in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('aún no se guarda'), findsOneWidget);
    expect(find.textContaining('listo para guardar'), findsNothing);
    expect(repo.uploaded, isEmpty);
  });

  testWidgets(
    'carga puntos reales en la gráfica y filas con diferencia semanal al abrir',
    (tester) async {
      final metrics = FakeProgressMetricsRepository(
        series: ProgressSeries(
          from: '2026-10-24',
          to: '2026-11-22',
          count: 3,
          latest: sampleBodyMetric(
            id: 'm-3',
            measuredAt: DateTime.utc(2026, 11, 22, 12),
            weightKg: 74.2,
            bodyFatPercent: 18.5,
            waistCm: 82.0,
          ),
          points: [
            sampleSeriesPoint(
              id: 'm-1',
              measuredAt: DateTime.utc(2026, 11, 8, 12),
              weightKg: 76.0,
            ),
            sampleSeriesPoint(
              id: 'm-2',
              measuredAt: DateTime.utc(2026, 11, 15, 12),
              weightKg: 75.0,
            ),
            sampleSeriesPoint(
              id: 'm-3',
              measuredAt: DateTime.utc(2026, 11, 22, 12),
              weightKg: 74.2,
              bodyFatPercent: 18.5,
              waistCm: 82.0,
            ),
          ],
        ),
        history: [
          sampleBodyMetric(
            id: 'm-3',
            measuredAt: DateTime.utc(2026, 11, 22, 12),
            weightKg: 74.2,
            bodyFatPercent: 18.5,
            waistCm: 82.0,
          ),
          sampleBodyMetric(
            id: 'm-2',
            measuredAt: DateTime.utc(2026, 11, 15, 12),
            weightKg: 75.0,
          ),
          sampleBodyMetric(
            id: 'm-1',
            measuredAt: DateTime.utc(2026, 11, 8, 12),
            weightKg: 76.0,
          ),
        ],
      );
      final vm = ProgressViewModel(
        photos: FakeProgressPhotosRepository(),
        metrics: metrics,
        clock: () => DateTime.utc(2026, 11, 22, 12),
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(home: ProgressShellPage(viewModel: vm)),
      );
      await tester.pumpAndSettle();

      expect(metrics.seriesRequests, hasLength(1));
      expect(metrics.historyRequests, hasLength(1));

      final chartCard = find.byType(ProgressWeightChartCard);
      expect(
        find.descendant(of: chartCard, matching: find.byType(CustomPaint)),
        findsWidgets,
      );
      expect(
        find.descendant(of: chartCard, matching: find.text('74.2 kg')),
        findsWidgets,
      );
      expect(
        find.descendant(of: chartCard, matching: find.text('-1.8 kg')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chartCard, matching: find.text('8 nov')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chartCard, matching: find.text('22 nov')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byType(ProgressHistoryCard),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final historyCard = find.byType(ProgressHistoryCard);
      expect(
        find.descendant(
          of: historyCard,
          matching: find.text('-0.8 kg vs sem. ant.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: historyCard,
          matching: find.text('-1.0 kg vs sem. ant.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: historyCard, matching: find.text('Base')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: historyCard,
          matching: find.text('Grasa: 18.5% | Cintura: 82 cm'),
        ),
        findsOneWidget,
      );

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
    },
  );

  testWidgets(
    'cambiar rango (7d, 30d, 90d, 1y) actualiza gráfica e historial',
    (tester) async {
      ProgressSeries buildSeries(
        String id,
        DateTime firstDate,
        double firstKg,
        double lastKg,
      ) {
        final latest = sampleBodyMetric(
          id: '$id-2',
          measuredAt: DateTime.utc(2026, 11, 22, 12),
          weightKg: lastKg,
        );
        return ProgressSeries(
          from: null,
          to: '2026-11-22',
          count: 2,
          latest: latest,
          points: [
            sampleSeriesPoint(
              id: '$id-1',
              measuredAt: firstDate,
              weightKg: firstKg,
            ),
            sampleSeriesPoint(
              id: '$id-2',
              measuredAt: DateTime.utc(2026, 11, 22, 12),
              weightKg: lastKg,
            ),
          ],
        );
      }

      List<BodyMetric> buildHistory(
        String id,
        DateTime firstDate,
        double firstKg,
        double lastKg,
      ) => [
        sampleBodyMetric(
          id: '$id-2',
          measuredAt: DateTime.utc(2026, 11, 22, 12),
          weightKg: lastKg,
        ),
        sampleBodyMetric(id: '$id-1', measuredAt: firstDate, weightKg: firstKg),
      ];

      final metrics = _RangeAwareMetricsRepository(
        seriesByFrom: {
          '2026-11-16': buildSeries(
            '7d',
            DateTime.utc(2026, 11, 18, 12),
            74.6,
            74.1,
          ),
          '2026-10-24': buildSeries(
            '30d',
            DateTime.utc(2026, 11, 1, 12),
            75.5,
            74.2,
          ),
          '2026-08-25': buildSeries(
            '90d',
            DateTime.utc(2026, 9, 10, 12),
            78.0,
            74.3,
          ),
          '2025-11-23': buildSeries(
            '1y',
            DateTime.utc(2026, 1, 15, 12),
            82.0,
            74.4,
          ),
        },
        historyByFrom: {
          '2026-11-16': buildHistory(
            '7d',
            DateTime.utc(2026, 11, 18, 12),
            74.6,
            74.1,
          ),
          '2026-10-24': buildHistory(
            '30d',
            DateTime.utc(2026, 11, 1, 12),
            75.5,
            74.2,
          ),
          '2026-08-25': buildHistory(
            '90d',
            DateTime.utc(2026, 9, 10, 12),
            78.0,
            74.3,
          ),
          '2025-11-23': buildHistory(
            '1y',
            DateTime.utc(2026, 1, 15, 12),
            82.0,
            74.4,
          ),
        },
      );
      final vm = ProgressViewModel(
        photos: FakeProgressPhotosRepository(),
        metrics: metrics,
        clock: () => DateTime.utc(2026, 11, 22, 12),
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(home: ProgressShellPage(viewModel: vm)),
      );
      await tester.pumpAndSettle();

      final chartCard = find.byType(ProgressWeightChartCard);
      expect(find.text('Últimos 30 días'), findsOneWidget);
      expect(
        find.descendant(of: chartCard, matching: find.text('74.2 kg')),
        findsWidgets,
      );

      for (final step in [
        (
          label: '7d',
          subtitle: 'Últimos 7 días',
          weight: '74.1 kg',
          diff: '-0.5 kg vs sem. ant.',
        ),
        (
          label: '90d',
          subtitle: 'Últimos 90 días',
          weight: '74.3 kg',
          diff: '-3.7 kg vs sem. ant.',
        ),
        (
          label: '1y',
          subtitle: 'Último año',
          weight: '74.4 kg',
          diff: '-7.6 kg vs sem. ant.',
        ),
        (
          label: '30d',
          subtitle: 'Últimos 30 días',
          weight: '74.2 kg',
          diff: '-1.3 kg vs sem. ant.',
        ),
      ]) {
        await tester.scrollUntilVisible(
          find.byType(ProgressRangeSelector),
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        final rangeChip = find.descendant(
          of: find.byType(ProgressRangeSelector),
          matching: find.text(step.label),
        );
        await tester.ensureVisible(rangeChip);
        await tester.pumpAndSettle();
        await tester.tap(rangeChip);
        await tester.pumpAndSettle();

        expect(find.text(step.subtitle), findsOneWidget);
        expect(
          find.descendant(of: chartCard, matching: find.text(step.weight)),
          findsWidgets,
        );

        await tester.scrollUntilVisible(
          find.byType(ProgressHistoryCard),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.descendant(
            of: find.byType(ProgressHistoryCard),
            matching: find.text(step.diff),
          ),
          findsOneWidget,
        );
      }

      expect(metrics.seriesRequests.map((r) => r.from).toList(), [
        '2026-10-24',
        '2026-11-16',
        '2026-08-25',
        '2025-11-23',
        '2026-10-24',
      ]);
    },
  );

  testWidgets(
    'check-in con peso, medidas opcionales y foto limpia formulario y actualiza Inicial vs Actual',
    (tester) async {
      final metrics = FakeProgressMetricsRepository();
      final photos = FakeProgressPhotosRepository();
      var now = DateTime.utc(2026, 11, 15, 12);
      var pickIndex = 0;
      final picks = [XFile('/tmp/inicial.jpg'), XFile('/tmp/actual.jpg')];

      final vm = ProgressViewModel(
        photos: photos,
        metrics: metrics,
        clock: () => now,
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ProgressShellPage(
            viewModel: vm,
            pickCheckInPhoto: () async => picks[pickIndex++],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Primer check-in para poblar foto Inicial con su peso real.
      await tester.ensureVisible(fieldFor('checkin-weight-field'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldFor('checkin-weight-field'), '75.0');
      await tapSelectPhoto(tester);
      await tester.ensureVisible(find.text('Guardar check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar check-in'));
      await tester.pumpAndSettle();

      expect(find.text('Check-in registrado correctamente.'), findsOneWidget);

      // Segundo check-in 7 días después con peso, grasa, cintura, nota y foto.
      now = DateTime.utc(2026, 11, 22, 12);
      await tester.ensureVisible(fieldFor('checkin-weight-field'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldFor('checkin-weight-field'), '74.2');
      await tester.enterText(fieldFor('checkin-body-fat-field'), '18.5');
      await tester.enterText(fieldFor('checkin-waist-field'), '81.5');
      await tester.enterText(fieldFor('checkin-notes-field'), 'En ayunas');
      await tapSelectPhoto(tester);

      await tester.ensureVisible(find.text('Guardar check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar check-in'));
      await tester.pumpAndSettle();

      expect(metrics.created, hasLength(2));
      expect(metrics.created.last.weightKg, 74.2);
      expect(metrics.created.last.bodyFatPercent, 18.5);
      expect(metrics.created.last.waistCm, 81.5);
      expect(photos.uploadedMetricIds, ['metric-1', 'metric-2']);

      for (final key in [
        'checkin-weight-field',
        'checkin-body-fat-field',
        'checkin-waist-field',
        'checkin-notes-field',
      ]) {
        expect(tester.widget<TextField>(fieldFor(key)).controller!.text, '');
      }

      await tester.scrollUntilVisible(
        find.byType(ProgressHistoryCard),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(
          of: find.byType(ProgressHistoryCard),
          matching: find.text('Grasa: 18.5% | Cintura: 81.5 cm | En ayunas'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProgressHistoryCard),
          matching: find.text('-0.8 kg vs sem. ant.'),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byType(ProgressPhotoComparisonCard),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final comparisonCard = find.byType(ProgressPhotoComparisonCard);
      expect(
        find.descendant(of: comparisonCard, matching: find.text('Inicial')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: comparisonCard, matching: find.text('Actual')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: comparisonCard, matching: find.text('75.0 kg')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: comparisonCard, matching: find.text('74.2 kg')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: comparisonCard, matching: find.text('Sin métrica')),
        findsNothing,
      );
    },
  );
}
