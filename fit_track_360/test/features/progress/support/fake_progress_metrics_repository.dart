import 'package:fit_track_360/features/progress/domain/body_metric.dart';
import 'package:fit_track_360/features/progress/domain/progress_metrics_repository.dart';

/// Serie vacía reutilizable en pruebas.
ProgressSeries emptyProgressSeries() => const ProgressSeries(
  from: null,
  to: null,
  count: 0,
  latest: null,
  points: [],
);

/// Medición de ejemplo con valores sobrescribibles.
BodyMetric sampleBodyMetric({
  String id = 'metric-1',
  String userId = 'user-1',
  DateTime? measuredAt,
  double? weightKg = 70,
  double? bodyFatPercent,
  double? waistCm,
}) {
  return BodyMetric(
    id: id,
    userId: userId,
    measuredAt: measuredAt ?? DateTime.utc(2026, 11, 22, 12),
    weightKg: weightKg,
    bodyFatPercent: bodyFatPercent,
    waistCm: waistCm,
  );
}

/// Punto de serie de ejemplo.
ProgressSeriesPoint sampleSeriesPoint({
  String id = 'metric-1',
  DateTime? measuredAt,
  double? weightKg = 70,
  double? bodyFatPercent,
  double? waistCm,
}) {
  final date = measuredAt ?? DateTime.utc(2026, 11, 22, 12);
  return ProgressSeriesPoint(
    id: id,
    date: _dateOnly(date),
    measuredAt: date,
    weightKg: weightKg,
    bodyFatPercent: bodyFatPercent,
    waistCm: waistCm,
  );
}

/// Doble en memoria de [ProgressMetricsRepository] para pruebas de VM.
class FakeProgressMetricsRepository implements ProgressMetricsRepository {
  FakeProgressMetricsRepository({
    ProgressSeries? series,
    List<BodyMetric>? history,
    this.latest,
    this.createError,
    this.listError,
    this.seriesError,
    this.latestError,
    this.deleteError,
    this.mutateOnCreate = true,
  }) : series = series ?? emptyProgressSeries(),
       history = history ?? const [];

  ProgressSeries series;
  List<BodyMetric> history;
  BodyMetric? latest;

  Object? createError;
  Object? listError;
  Object? seriesError;
  Object? latestError;
  Object? deleteError;

  /// Si es true, `create` agrega la métrica a [history] y [series].
  bool mutateOnCreate;

  final List<CreateBodyMetricInput> created = [];
  final List<String> deleted = [];
  final List<({String? from, String? to})> historyRequests = [];
  final List<({String? from, String? to})> seriesRequests = [];
  int latestCalls = 0;

  @override
  Future<BodyMetric> create(CreateBodyMetricInput input) async {
    final error = createError;
    if (error != null) throw error;

    created.add(input);
    final metric = BodyMetric(
      id: 'metric-${created.length}',
      userId: 'user-1',
      measuredAt: input.measuredAt,
      weightKg: input.weightKg,
      bodyFatPercent: input.bodyFatPercent,
      waistCm: input.waistCm,
    );
    latest = metric;

    if (mutateOnCreate) {
      history = [metric, ...history];
      final points = [
        ...series.points,
        sampleSeriesPoint(
          id: metric.id,
          measuredAt: metric.measuredAt,
          weightKg: metric.weightKg,
          bodyFatPercent: metric.bodyFatPercent,
          waistCm: metric.waistCm,
        ),
      ]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      series = ProgressSeries(
        from: series.from,
        to: series.to,
        count: points.length,
        latest: metric,
        points: points,
      );
    }
    return metric;
  }

  @override
  Future<List<BodyMetric>> listHistory({String? from, String? to}) async {
    final error = listError;
    if (error != null) throw error;
    historyRequests.add((from: from, to: to));
    return List.unmodifiable(history);
  }

  @override
  Future<ProgressSeries> getSeries({String? from, String? to}) async {
    final error = seriesError;
    if (error != null) throw error;
    seriesRequests.add((from: from, to: to));
    return series;
  }

  @override
  Future<BodyMetric?> getLatest() async {
    final error = latestError;
    if (error != null) throw error;
    latestCalls++;
    return latest;
  }

  @override
  Future<void> delete(String id) async {
    final error = deleteError;
    if (error != null) throw error;
    deleted.add(id);
    history = history.where((metric) => metric.id != id).toList();
    final points = series.points.where((point) => point.id != id).toList();
    series = ProgressSeries(
      from: series.from,
      to: series.to,
      count: points.length,
      latest: series.latest,
      points: points,
    );
  }
}

String _dateOnly(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-$month-$day';
}
