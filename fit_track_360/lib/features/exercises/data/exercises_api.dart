import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import 'exercise.dart';

/// Cliente del catálogo de ejercicios.
///
/// Los endpoints `GET /api/v1/exercises` y `GET /api/v1/exercises/:id`, y el
/// sobre `{items, total, page, pageSize}`, todavía no están confirmados con
/// backend. Todo el acoplamiento a ese contrato se concentra en este archivo.
class ExercisesApi {
  static const String collectionPath = '/api/v1/exercises';
  static const int defaultPageSize = 20;

  /// Mensaje propio para un 404 del detalle, sin depender del cuerpo del error.
  static const String notFoundMessage = 'No encontramos ese ejercicio.';

  final ApiClient _client;

  ExercisesApi(this._client);

  /// Lista paginada del catálogo. Los filtros vacíos no se envían.
  Future<ExercisePage> fetchPage({
    String? query,
    String? bodyPart,
    String? equipment,
    String? target,
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    final response = await _client.get(
      buildCollectionPath(
        query: query,
        bodyPart: bodyPart,
        equipment: equipment,
        target: target,
        page: page,
        pageSize: pageSize,
      ),
    );

    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }

    return ExercisePage.fromJson(
      _decode(response.bodyBytes),
      page: page,
      pageSize: pageSize,
    );
  }

  /// Detalle por id; un 404 se traduce a un mensaje propio.
  Future<Exercise> fetchById(String id) async {
    final response = await _client.get(
      '${ExercisesApi.collectionPath}/${Uri.encodeComponent(id)}',
    );

    if (response.statusCode == 404) {
      throw const AuthApiException(ExercisesApi.notFoundMessage);
    }
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }

    final body = _decode(response.bodyBytes);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de ejercicio inválida');
    }
    return Exercise.fromJson(body);
  }

  /// Ruta con los query params ya codificados. Público para probar los filtros.
  static String buildCollectionPath({
    String? query,
    String? bodyPart,
    String? equipment,
    String? target,
    required int page,
    required int pageSize,
  }) {
    final params = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (_isFilled(query)) 'q': query!.trim(),
      if (_isFilled(bodyPart)) 'bodyPart': bodyPart!.trim(),
      if (_isFilled(equipment)) 'equipment': equipment!.trim(),
      if (_isFilled(target)) 'target': target!.trim(),
    };
    return Uri(
      path: ExercisesApi.collectionPath,
      queryParameters: params,
    ).toString();
  }

  static bool _isFilled(String? value) =>
      value != null && value.trim().isNotEmpty;

  static Object? _decode(List<int> bodyBytes) {
    final text = utf8.decode(bodyBytes);
    if (text.trim().isEmpty) {
      throw const FormatException('Respuesta de ejercicios vacía');
    }
    return jsonDecode(text);
  }
}
