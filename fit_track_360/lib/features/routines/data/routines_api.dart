import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import 'routines_reader.dart';

/// Lectura de rutinas por HTTP.
///
/// El módulo `routines` todavía no existe en el API; las rutas y la forma de
/// la respuesta siguen el plan del proyecto y quedan pendientes de confirmar
/// con backend. Todo el acoplamiento a ese contrato vive en este archivo.
class RoutinesApi implements RoutinesReader {
  final ApiClient _client;

  RoutinesApi(this._client);

  @override
  Future<List<RoutineSummary>> list() async {
    final response = await _client.get('/api/v1/routines');
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    return _items(jsonDecode(utf8.decode(response.bodyBytes)))
        .map(RoutineSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<RoutineDetail> getById(String id) async {
    final response = await _client.get(
      '/api/v1/routines/${Uri.encodeComponent(id)}',
    );
    if (response.statusCode == 404) {
      throw const RoutineNotFoundException();
    }
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const AuthApiException('No se pudo conectar');
    }
    return RoutineDetail.fromJson(body);
  }

  /// Acepta una lista directa o un sobre `{items: [...]}` mientras el
  /// contrato de listado no esté confirmado.
  List<Map<String, dynamic>> _items(Object? body) {
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (body is Map<String, dynamic> && body['items'] is List) {
      return (body['items'] as List).whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
    }
    throw const AuthApiException('No se pudo conectar');
  }
}
