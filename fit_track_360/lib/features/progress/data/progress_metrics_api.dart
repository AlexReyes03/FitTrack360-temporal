import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../domain/body_metric.dart';
import '../domain/progress_metric_errors.dart';
import '../domain/progress_metrics_repository.dart';

export '../domain/progress_metric_errors.dart';

/// Cliente de `POST/GET/DELETE /api/v1/progress`.
///
/// Ownership: métrica ajena o inexistente → 404 del API →
/// [ProgressMetricNotFoundException] (sin filtrar existencia).
class ProgressMetricsApi implements ProgressMetricsRepository {
  ProgressMetricsApi(this._client);

  final ApiClient _client;

  static const _path = '/api/v1/progress';

  @override
  Future<BodyMetric> create(CreateBodyMetricInput input) async {
    final response = await _client.post(_path, body: input.toJson());
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw _error(response);
    }
    return BodyMetric.fromJson(_decodeMap(response));
  }

  @override
  Future<List<BodyMetric>> listHistory({String? from, String? to}) async {
    final response = await _client.get(_withRange(_path, from: from, to: to));
    if (response.statusCode != 200) throw _error(response);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) {
      throw const ProgressMetricRequestException(
        'Respuesta inválida del servidor',
      );
    }
    return body
        .whereType<Map<String, dynamic>>()
        .map(BodyMetric.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ProgressSeries> getSeries({String? from, String? to}) async {
    final response = await _client.get(
      _withRange('$_path/series', from: from, to: to),
    );
    if (response.statusCode != 200) throw _error(response);
    return ProgressSeries.fromJson(_decodeMap(response));
  }

  @override
  Future<BodyMetric?> getLatest() async {
    final response = await _client.get('$_path/latest');
    if (response.statusCode != 200) throw _error(response);
    final latest = _decodeMap(response)['metric'];
    return latest is Map<String, dynamic> ? BodyMetric.fromJson(latest) : null;
  }

  @override
  Future<void> delete(String id) async {
    final response = await _client.delete('$_path/${Uri.encodeComponent(id)}');
    if (response.statusCode == 204 || response.statusCode == 200) return;
    throw _error(response);
  }

  /// Construye `?from=YYYY-MM-DD&to=YYYY-MM-DD` sin enviar parámetros vacíos.
  static String _withRange(String path, {String? from, String? to}) {
    final params = <String, String>{
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    };
    if (params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const ProgressMetricRequestException(
        'Respuesta inválida del servidor',
      );
    }
    return body;
  }

  /// 400 → validación; 404 → no disponible (S4); resto → fallo de petición.
  static ProgressMetricException _error(http.Response response) {
    if (response.statusCode == 400) {
      return ProgressMetricValidationException(apiErrorMessage(response));
    }
    if (response.statusCode == 404) {
      return const ProgressMetricNotFoundException();
    }
    return ProgressMetricRequestException(apiErrorMessage(response));
  }
}
