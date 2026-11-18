import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import 'routines_reader.dart';

/// Cliente HTTP de rutinas (`/api/v1/routines`).
///
/// El detalle solo trae `exerciseId`, así que el nombre se resuelve contra el
/// catálogo (`/api/v1/exercises/:id`) y se degrada a «Ejercicio» si falla.
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
    final detail = RoutineDetail.fromJson(body);
    return detail.withExerciseNames(await _exerciseNames(detail.exercises));
  }

  /// Nombres del catálogo para los ejercicios que la rutina no incluye.
  Future<Map<String, String>> _exerciseNames(
    List<RoutineExerciseSummary> exercises,
  ) async {
    final pending = <String>{};
    for (final exercise in exercises) {
      final id = exercise.exerciseId;
      if (exercise.exerciseName == null && id != null) pending.add(id);
    }
    if (pending.isEmpty) return const {};

    final entries = await Future.wait(pending.map(_exerciseName));
    return {
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<MapEntry<String, String?>> _exerciseName(String id) async {
    try {
      final response = await _client.get(
        '/api/v1/exercises/${Uri.encodeComponent(id)}',
      );
      if (response.statusCode != 200) return MapEntry(id, null);
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) return MapEntry(id, null);
      return MapEntry(
        id,
        _optionalText(body['nameEs']) ?? _optionalText(body['name']),
      );
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return MapEntry(id, null);
    }
  }

  /// Acepta un arreglo directo o un sobre `{items: [...]}`.
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

String? _optionalText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}
