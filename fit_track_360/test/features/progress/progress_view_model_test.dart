import 'dart:io';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/progress/domain/body_metric.dart';
import 'package:fit_track_360/features/progress/domain/progress_metric_errors.dart';
import 'package:fit_track_360/features/progress/domain/progress_photo_errors.dart';
import 'package:fit_track_360/features/progress/presentation/progress_view_model.dart';
import 'package:fit_track_360/features/progress/presentation/state/progress_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_progress_metrics_repository.dart';
import 'support/fake_progress_photos_repository.dart';

const _draft = ProgressCheckInDraft(
  weightKg: 74.2,
  notesText: '',
  hasPhotoSelected: false,
);

final DateTime _now = DateTime.utc(2026, 11, 22, 12);

File _photo(String name) => File('${Directory.systemTemp.path}/$name');

ProgressViewModel _metricsVm(
  FakeProgressMetricsRepository metrics, {
  FakeProgressPhotosRepository? photos,
}) {
  return ProgressViewModel(
    photos: photos ?? FakeProgressPhotosRepository(),
    metrics: metrics,
    clock: () => _now,
  );
}

ProgressSeries _series(List<ProgressSeriesPoint> points) {
  return ProgressSeries(
    from: null,
    to: null,
    count: points.length,
    latest: null,
    points: points,
  );
}

void main() {
  test('métricas quedan empty por bloqueo #122', () {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());

    expect(vm.chartStatus, ProgressSectionStatus.empty);
    expect(vm.historyStatus, ProgressSectionStatus.empty);
    expect(vm.chartAsync, isA<AsyncEmpty>());
    expect(vm.historyAsync, isA<AsyncEmpty>());
    expect(vm.chartData.points, isEmpty);
    expect(vm.historyEntries, isEmpty);

    vm.setRange(ProgressRange.y1);
    expect(vm.range, ProgressRange.y1);
    expect(vm.chartStatus, ProgressSectionStatus.empty);

    vm.dispose();
  });

  test('reintentar recarga métricas aunque el rango no cambie', () {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());
    var notifications = 0;
    vm.addListener(() => notifications++);

    vm.setRange(vm.range);
    expect(notifications, 0, reason: 'mismo rango sin forzar no recarga');

    vm.reloadMetrics();
    expect(notifications, greaterThan(0));
    expect(vm.chartStatus, ProgressSectionStatus.empty);
    expect(vm.historyStatus, ProgressSectionStatus.empty);

    vm.dispose();
  });

  test('check-in sin foto dice que el peso aún no se guarda', () async {
    final repo = FakeProgressPhotosRepository();
    final vm = ProgressViewModel(photos: repo);

    await vm.submitCheckIn(_draft);

    expect(vm.checkInFeedback, contains('aún no se guarda'));
    expect(vm.checkInFeedback, contains('#122'));
    expect(vm.checkInFeedback, isNot(contains('listo para guardar')));
    expect(repo.uploaded, isEmpty);
    expect(vm.sessionPhotos, isEmpty);

    vm.dispose();
  });

  test('check-in con foto sube y arma comparación de sesión', () async {
    final repo = FakeProgressPhotosRepository();
    final vm = ProgressViewModel(photos: repo);

    vm.selectPendingPhoto(_photo('a.jpg'), label: 'selfie.jpg');
    await vm.submitCheckIn(_draft);

    expect(repo.uploaded, hasLength(1));
    expect(vm.sessionPhotos, hasLength(1));
    expect(vm.comparisonStatus, ProgressSectionStatus.data);
    expect(vm.checkInFeedback, contains('Foto guardada'));
    expect(vm.checkInFeedback, contains('aún no se guarda'));
    expect(vm.selectedCheckInPhotoLabel, isNull);

    vm.selectPendingPhoto(_photo('b.jpg'), label: 'selfie2.jpg');
    await vm.submitCheckIn(_draft);

    expect(vm.sessionPhotos, hasLength(2));
    expect(vm.sessionComparison!.initial!.id, 'ph-1');
    expect(vm.sessionComparison!.current!.id, 'ph-2');

    vm.dispose();
  });

  test('sesión expirada al subir marca sessionExpired', () async {
    final vm = ProgressViewModel(
      photos: FakeProgressPhotosRepository(
        uploadError: const SessionExpiredException(),
      ),
    );
    vm.selectPendingPhoto(_photo('a.jpg'), label: 'a.jpg');

    await vm.submitCheckIn(_draft);

    expect(vm.sessionExpired, isTrue);
    expect(vm.isSubmittingCheckIn, isFalse);
    vm.dispose();
  });

  test('error de validación de foto se muestra sin tumbar el VM', () async {
    final vm = ProgressViewModel(
      photos: FakeProgressPhotosRepository(
        uploadError: const ProgressPhotoValidationException('Formato raro'),
      ),
    );
    vm.selectPendingPhoto(_photo('a.jpg'), label: 'a.jpg');

    await vm.submitCheckIn(_draft);

    expect(vm.checkInFeedback, 'Formato raro');
    vm.dispose();
  });

  test('reintentar comparación recalcula los slots de la sesión', () async {
    final vm = ProgressViewModel(photos: FakeProgressPhotosRepository());
    await vm.uploadProgressPhoto(_photo('a.jpg'));
    vm.comparisonStatus = ProgressSectionStatus.error;

    vm.refreshComparison();

    expect(vm.comparisonStatus, ProgressSectionStatus.data);
    expect(vm.initialPhotoSlot, isNotNull);
    vm.dispose();
  });

  test('delete 404 de foto ajena no tumba el VM', () async {
    final vm = ProgressViewModel(
      photos: FakeProgressPhotosRepository(
        deleteError: const ProgressPhotoUnavailableException(),
      ),
    );

    await expectLater(
      vm.deletePhoto('ajena'),
      throwsA(isA<ProgressPhotoUnavailableException>()),
    );

    vm.dispose();
  });

  group('métricas reales', () {
    const rangeCases = [
      (ProgressRange.d7, '2026-11-16'),
      (ProgressRange.d30, '2026-10-24'),
      (ProgressRange.d90, '2026-08-25'),
      (ProgressRange.y1, '2025-11-23'),
    ];

    for (final (range, from) in rangeCases) {
      test('el rango ${range.label} consulta $from a 2026-11-22', () async {
        final metrics = FakeProgressMetricsRepository();
        final vm = _metricsVm(metrics);

        vm.setRange(range);
        await vm.reloadMetrics();

        expect(metrics.seriesRequests.last, (from: from, to: '2026-11-22'));
        expect(metrics.historyRequests.last, (from: from, to: '2026-11-22'));

        vm.dispose();
      });
    }

    test('calcula peso actual, delta, promedio y puntos de la serie', () async {
      final metrics = FakeProgressMetricsRepository(
        series: _series([
          sampleSeriesPoint(
            id: 'm1',
            measuredAt: DateTime.utc(2026, 11, 16, 12),
            weightKg: 70,
          ),
          sampleSeriesPoint(
            id: 'm2',
            measuredAt: DateTime.utc(2026, 11, 19, 12),
            weightKg: 72,
          ),
          sampleSeriesPoint(
            id: 'm3',
            measuredAt: DateTime.utc(2026, 11, 22, 12),
            weightKg: 71,
          ),
        ]),
        history: [
          sampleBodyMetric(
            id: 'm3',
            measuredAt: DateTime.utc(2026, 11, 22, 12),
            weightKg: 71,
            bodyFatPercent: 18.2,
            waistCm: 81.5,
          ),
          sampleBodyMetric(
            id: 'm2',
            measuredAt: DateTime.utc(2026, 11, 19, 12),
            weightKg: 72,
          ),
          sampleBodyMetric(
            id: 'm1',
            measuredAt: DateTime.utc(2026, 11, 16, 12),
            weightKg: 70,
          ),
        ],
      );
      final vm = _metricsVm(metrics);

      await vm.reloadMetrics();

      expect(vm.chartStatus, ProgressSectionStatus.data);
      expect(vm.chartData.currentWeightKg, 71);
      expect(vm.chartData.periodDeltaKg, closeTo(1, 1e-9));
      expect(vm.chartData.averageWeightKg, closeTo(71, 1e-9));
      expect(vm.chartData.points.map((point) => point.weightKg), [70, 72, 71]);

      vm.dispose();
    });

    test(
      'historial calcula diferencia semanal y nota de indicadores',
      () async {
        final metrics = FakeProgressMetricsRepository(
          history: [
            sampleBodyMetric(
              id: 'm3',
              measuredAt: DateTime.utc(2026, 11, 22, 12),
              weightKg: 71,
              bodyFatPercent: 18.2,
              waistCm: 81.5,
            ),
            sampleBodyMetric(
              id: 'm2',
              measuredAt: DateTime.utc(2026, 11, 19, 12),
              weightKg: 72,
            ),
            sampleBodyMetric(
              id: 'm1',
              measuredAt: DateTime.utc(2026, 11, 16, 12),
              weightKg: 70,
            ),
          ],
        );
        final vm = _metricsVm(metrics);

        await vm.reloadMetrics();

        expect(vm.historyStatus, ProgressSectionStatus.data);
        expect(vm.historyEntries, hasLength(3));
        expect(vm.historyEntries[0].weightKg, 71);
        expect(vm.historyEntries[0].weeklyDiffKg, closeTo(1, 1e-9));
        expect(vm.historyEntries[1].weeklyDiffKg, closeTo(2, 1e-9));
        expect(vm.historyEntries[2].weeklyDiffKg, isNull);
        expect(vm.historyEntries[0].note, contains('Grasa: 18.2%'));
        expect(vm.historyEntries[0].note, contains('Cintura: 81.5 cm'));

        vm.dispose();
      },
    );

    test('sin puntos deja gráfica e historial vacíos', () async {
      final vm = _metricsVm(FakeProgressMetricsRepository());

      await vm.reloadMetrics();

      expect(vm.chartStatus, ProgressSectionStatus.empty);
      expect(vm.historyStatus, ProgressSectionStatus.empty);
      expect(vm.chartAsync, isA<AsyncEmpty>());
      expect(vm.historyAsync, isA<AsyncEmpty>());

      vm.dispose();
    });

    test('mientras carga expone loading y luego data', () async {
      final metrics = FakeProgressMetricsRepository(
        series: _series([
          sampleSeriesPoint(
            measuredAt: DateTime.utc(2026, 11, 22, 12),
            weightKg: 71,
          ),
        ]),
        history: [
          sampleBodyMetric(
            measuredAt: DateTime.utc(2026, 11, 22, 12),
            weightKg: 71,
          ),
        ],
      );
      final vm = _metricsVm(metrics);

      final loading = vm.reloadMetrics();

      expect(vm.chartStatus, ProgressSectionStatus.loading);
      expect(vm.historyStatus, ProgressSectionStatus.loading);
      expect(vm.chartAsync, isA<AsyncLoading>());

      await loading;

      expect(vm.chartStatus, ProgressSectionStatus.data);
      expect(vm.historyStatus, ProgressSectionStatus.data);

      vm.dispose();
    });

    test('un error de red deja gráfica e historial en error', () async {
      final metrics = FakeProgressMetricsRepository(
        seriesError: Exception('sin red'),
      );
      final vm = _metricsVm(metrics);

      await vm.reloadMetrics();

      expect(vm.chartStatus, ProgressSectionStatus.error);
      expect(vm.historyStatus, ProgressSectionStatus.error);
      expect(vm.chartAsync, isA<AsyncError>());
      expect(vm.historyAsync, isA<AsyncError>());

      vm.dispose();
    });

    test('sesión expirada al cargar marca sessionExpired', () async {
      final metrics = FakeProgressMetricsRepository(
        seriesError: const SessionExpiredException(),
      );
      final vm = _metricsVm(metrics);

      await vm.reloadMetrics();

      expect(vm.sessionExpired, isTrue);
      expect(vm.chartStatus, ProgressSectionStatus.error);

      vm.dispose();
    });

    test(
      'check-in de solo métrica crea, recarga y guarda nota local',
      () async {
        final metrics = FakeProgressMetricsRepository();
        final photos = FakeProgressPhotosRepository();
        final vm = _metricsVm(metrics, photos: photos);

        await vm.submitCheckIn(
          const ProgressCheckInDraft(
            weightKg: 74.2,
            notesText: 'Buen descanso',
            hasPhotoSelected: false,
            bodyFatPercent: 18.2,
            waistCm: 81.5,
          ),
        );

        expect(metrics.created, hasLength(1));
        expect(metrics.created.single.measuredAt, _now);
        expect(metrics.created.single.weightKg, 74.2);
        expect(metrics.created.single.bodyFatPercent, 18.2);
        expect(metrics.created.single.waistCm, 81.5);
        expect(photos.uploaded, isEmpty);
        expect(vm.checkInFeedback, 'Check-in registrado correctamente.');
        expect(vm.isSubmittingCheckIn, isFalse);
        expect(vm.chartStatus, ProgressSectionStatus.data);
        expect(vm.chartData.currentWeightKg, 74.2);
        expect(vm.historyEntries.first.note, contains('Buen descanso'));
        expect(vm.historyEntries.first.note, contains('Grasa: 18.2%'));

        vm.dispose();
      },
    );

    test('check-in con foto vincula metricId y muestra el peso real', () async {
      final metrics = FakeProgressMetricsRepository();
      final photos = FakeProgressPhotosRepository();
      final vm = _metricsVm(metrics, photos: photos);

      vm.selectPendingPhoto(_photo('a.jpg'), label: 'a.jpg');
      await vm.submitCheckIn(_draft);

      expect(metrics.created, hasLength(1));
      expect(photos.uploadedMetricIds, ['metric-1']);
      expect(vm.sessionPhotos, hasLength(1));
      expect(vm.initialPhotoSlot!.weightLabel, '74.2 kg');
      expect(vm.currentPhotoSlot, isNull);
      expect(vm.selectedCheckInPhotoLabel, isNull);
      expect(vm.checkInFeedback, 'Check-in registrado correctamente.');

      vm.selectPendingPhoto(_photo('b.jpg'), label: 'b.jpg');
      await vm.submitCheckIn(
        const ProgressCheckInDraft(
          weightKg: 73.8,
          notesText: '',
          hasPhotoSelected: true,
        ),
      );

      expect(photos.uploadedMetricIds, ['metric-1', 'metric-2']);
      expect(vm.initialPhotoSlot!.weightLabel, '74.2 kg');
      expect(vm.currentPhotoSlot!.weightLabel, '73.8 kg');
      expect(vm.sessionComparison!.initial!.id, 'ph-1');
      expect(vm.sessionComparison!.current!.id, 'ph-2');

      vm.dispose();
    });

    test('validación del API se muestra en el formulario', () async {
      final metrics = FakeProgressMetricsRepository(
        createError: const ProgressMetricValidationException('Peso inválido'),
      );
      final vm = _metricsVm(metrics);

      await vm.submitCheckIn(_draft);

      expect(vm.checkInFeedback, 'Peso inválido');
      expect(vm.isSubmittingCheckIn, isFalse);

      vm.dispose();
    });

    test('404 al crear se muestra sin filtrar existencia', () async {
      final metrics = FakeProgressMetricsRepository(
        createError: const ProgressMetricNotFoundException(),
      );
      final vm = _metricsVm(metrics);

      await vm.submitCheckIn(_draft);

      expect(vm.checkInFeedback, 'Métrica no disponible');

      vm.dispose();
    });

    test('sesión expirada al crear marca sessionExpired', () async {
      final metrics = FakeProgressMetricsRepository(
        createError: const SessionExpiredException(),
      );
      final vm = _metricsVm(metrics);

      await vm.submitCheckIn(_draft);

      expect(vm.sessionExpired, isTrue);
      expect(vm.checkInFeedback, 'Sesión expirada.');

      vm.dispose();
    });

    test('si falla la foto la métrica ya quedó creada', () async {
      final metrics = FakeProgressMetricsRepository();
      final photos = FakeProgressPhotosRepository(
        uploadError: const ProgressPhotoValidationException('Formato raro'),
      );
      final vm = _metricsVm(metrics, photos: photos);
      vm.selectPendingPhoto(_photo('a.jpg'), label: 'a.jpg');

      await vm.submitCheckIn(_draft);

      expect(metrics.created, hasLength(1));
      expect(vm.sessionPhotos, isEmpty);
      expect(vm.checkInFeedback, 'Formato raro');

      vm.dispose();
    });
  });
}
