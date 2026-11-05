import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import 'workout_session.dart';

class WorkoutsApi {
  final ApiClient _client;

  WorkoutsApi(this._client);

  Future<List<WorkoutSession>> list() async {
    final response = await _client.get('/api/v1/workouts');
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) {
      throw const AuthApiException('No se pudo conectar');
    }
    return body
        .map((item) => WorkoutSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WorkoutSession> create({
    required DateTime startedAt,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'startedAt': startedAt.toUtc().toIso8601String(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final response = await _client.post('/api/v1/workouts', body: payload);
    if (response.statusCode != 201) {
      throw AuthApiException(apiErrorMessage(response));
    }
    return WorkoutSession.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
