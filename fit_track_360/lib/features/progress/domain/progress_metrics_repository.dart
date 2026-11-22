import 'body_metric.dart';

/// Contrato de métricas corporales (`/api/v1/progress`). Lo implementa la capa
/// de datos; el ViewModel depende solo de esta interfaz.
///
/// Errores: [ProgressMetricValidationException] (400),
/// [ProgressMetricNotFoundException] (404, sin filtrar existencia),
/// [ProgressMetricRequestException] y `SessionExpiredException`.
abstract interface class ProgressMetricsRepository {
  Future<BodyMetric> create(CreateBodyMetricInput input);

  /// Historial descendente por `measuredAt`. [from] y [to] usan `YYYY-MM-DD`.
  Future<List<BodyMetric>> listHistory({String? from, String? to});

  /// Serie ascendente lista para graficar. [from] y [to] usan `YYYY-MM-DD`.
  Future<ProgressSeries> getSeries({String? from, String? to});

  Future<BodyMetric?> getLatest();

  Future<void> delete(String id);
}
