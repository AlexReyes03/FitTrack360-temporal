import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_today.dart';

typedef GetRequest = Future<http.Response> Function(String path);

/// Cliente de `GET /api/v1/dashboard/today` vía [ApiClient.get].
class DashboardApiRepository implements DashboardRepository {
  DashboardApiRepository({required this._get});

  factory DashboardApiRepository.fromClient(ApiClient client) =>
      DashboardApiRepository(get: client.get);

  final GetRequest _get;

  static const _path = '/api/v1/dashboard/today';

  @override
  Future<DashboardToday> today({
    required String date,
    required int utcOffsetMinutes,
  }) async {
    final path =
        '$_path?date=${Uri.encodeQueryComponent(date)}'
        '&utcOffsetMinutes=$utcOffsetMinutes';
    final response = await _get(path);
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const AuthApiException('No se pudo conectar');
    }
    return DashboardToday.fromJson(body);
  }
}
