import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/progress/data/progress_metrics_api.dart';
import 'package:fit_track_360/features/progress/domain/body_metric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStorage implements SessionStorage {
  _FakeStorage({this.access = 'access'});

  String? access;

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) access = access == null ? null : 'renewed';
    return access;
  }

  @override
  Future<String?> readRefreshToken() async => 'refresh';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {
    access = null;
  }
}

ProgressMetricsApi _api(MockClient client, {_FakeStorage? storage}) {
  return ProgressMetricsApi(
    ApiClient(storage: storage ?? _FakeStorage(), httpClient: client),
  );
}

Map<String, dynamic> _metricJson({
  String id = 'metric-1',
  String measuredAt = '2026-11-10T07:30:00.000Z',
  double weightKg = 74.5,
  double? bodyFatPercent = 18.2,
  double? waistCm = 81.5,
}) {
  return {
    'id': id,
    'userId': 'user-1',
    'measuredAt': measuredAt,
    'weightKg': weightKg,
    'bodyFatPercent': bodyFatPercent,
    'waistCm': waistCm,
  };
}

Map<String, dynamic> _pointJson({
  String id = 'metric-1',
  String date = '2026-11-10',
  String measuredAt = '2026-11-10T07:30:00.000Z',
  double weightKg = 74.5,
  double? bodyFatPercent = 18.2,
  double? waistCm = 81.5,
}) {
  return {
    'id': id,
    'date': date,
    'measuredAt': measuredAt,
    'weightKg': weightKg,
    'bodyFatPercent': bodyFatPercent,
    'waistCm': waistCm,
  };
}

void main() {
  test('POST /api/v1/progress envía solo campos permitidos y parsea', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(_metricJson()),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final metric = await api.create(
      CreateBodyMetricInput(
        measuredAt: DateTime.utc(2026, 11, 10, 7, 30),
        weightKg: 74.5,
        bodyFatPercent: 18.2,
        waistCm: 81.5,
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/progress');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['measuredAt'], '2026-11-10T07:30:00.000Z');
    expect(body['weightKg'], 74.5);
    expect(body['bodyFatPercent'], 18.2);
    expect(body['waistCm'], 81.5);
    expect(body.containsKey('notes'), isFalse);

    expect(metric.id, 'metric-1');
    expect(metric.userId, 'user-1');
    expect(metric.measuredAt, DateTime.utc(2026, 11, 10, 7, 30));
    expect(metric.weightKg, 74.5);
    expect(metric.bodyFatPercent, 18.2);
    expect(metric.waistCm, 81.5);
  });

  test('POST omite bodyFatPercent y waistCm cuando son null', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_metricJson()), 201);
      }),
    );

    await api.create(
      CreateBodyMetricInput(
        measuredAt: DateTime.utc(2026, 11, 10, 7, 30),
        weightKg: 74.5,
      ),
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body.keys, unorderedEquals(['measuredAt', 'weightKg']));
  });

  test('GET /api/v1/progress envía from y to y parsea el historial', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([_metricJson()]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final history = await api.listHistory(from: '2026-11-01', to: '2026-11-22');

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/progress');
    expect(captured.url.queryParameters, {
      'from': '2026-11-01',
      'to': '2026-11-22',
    });
    expect(history, hasLength(1));
    expect(history.single.weightKg, 74.5);
  });

  test('GET /api/v1/progress/series parsea puntos y latest', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'from': '2026-11-01T00:00:00.000Z',
            'to': '2026-11-22T23:59:59.999Z',
            'count': 1,
            'latest': _metricJson(),
            'points': [_pointJson()],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final series = await api.getSeries(from: '2026-11-01', to: '2026-11-22');

    expect(captured.url.path, '/api/v1/progress/series');
    expect(captured.url.queryParameters, {
      'from': '2026-11-01',
      'to': '2026-11-22',
    });
    expect(series.count, 1);
    expect(series.latest!.id, 'metric-1');
    expect(series.points.single.date, '2026-11-10');
    expect(series.points.single.weightKg, 74.5);
    expect(series.points.single.bodyFatPercent, 18.2);
  });

  test('GET /api/v1/progress/latest devuelve null sin métricas', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'metric': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final latest = await api.getLatest();

    expect(captured.url.path, '/api/v1/progress/latest');
    expect(latest, isNull);
  });

  test('GET /api/v1/progress/latest parsea la métrica', () async {
    final api = _api(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'metric': _metricJson()}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final latest = await api.getLatest();

    expect(latest!.id, 'metric-1');
    expect(latest.measuredAt, DateTime.utc(2026, 11, 10, 7, 30));
  });

  test('un 400 se reporta como validación de métrica', () async {
    final api = _api(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'weightKg debe ser mayor a 0'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.create(
        CreateBodyMetricInput(
          measuredAt: DateTime.utc(2026, 11, 10, 7, 30),
          weightKg: 0,
        ),
      ),
      throwsA(
        isA<ProgressMetricValidationException>().having(
          (error) => error.message,
          'message',
          'weightKg debe ser mayor a 0',
        ),
      ),
    );
  });

  test(
    'un 404 al borrar se reporta sin filtrar el mensaje del servidor',
    () async {
      final api = _api(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'message': 'Métrica corporal no encontrada'}),
            404,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      try {
        await api.delete('ajena');
        fail('Debió lanzar ProgressMetricNotFoundException');
      } on ProgressMetricNotFoundException catch (error) {
        expect(error.message, isNot(contains('encontrada')));
        expect(error.message, isNot(contains('ajena')));
      }
    },
  );

  test('delete 204 completa sin error', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    await api.delete('metric-1');

    expect(captured.method, 'DELETE');
    expect(captured.url.path, '/api/v1/progress/metric-1');
  });

  test('propaga la sesión expirada cuando no puede renovar', () async {
    final api = _api(
      MockClient((request) async => http.Response('', 401)),
      storage: _FakeStorage(access: null),
    );

    await expectLater(api.getSeries(), throwsA(isA<SessionExpiredException>()));
  });

  test('sin rango no agrega query params', () async {
    late http.Request captured;
    final api = _api(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'from': null,
            'to': null,
            'count': 0,
            'latest': null,
            'points': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await api.getSeries();

    expect(captured.url.query, isEmpty);
  });
}
