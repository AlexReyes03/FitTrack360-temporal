import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_type.dart';
import '../domain/meals_repository.dart';
import 'meal_notes_codec.dart';

typedef GetRequest = Future<http.Response> Function(String path);
typedef PostRequest = Future<http.Response> Function(
  String path,
  Map<String, dynamic> body,
);

/// MealsRepository contra `GET/POST /api/v1/meals` (contrato real de
/// CreateMealDto y MealResponseDto). No envía photoId: W11 no usa fotos.
class MealsApiRepository implements MealsRepository {
  MealsApiRepository({required this._get, required this._post});

  factory MealsApiRepository.fromClient(ApiClient client) => MealsApiRepository(
    get: client.get,
    post: (path, body) => client.post(path, body: body),
  );

  final GetRequest _get;
  final PostRequest _post;

  static const _path = '/api/v1/meals';

  @override
  Future<List<MealEntry>> list() async {
    final response = await _get(_path);
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) throw const AuthApiException('No se pudo conectar');
    return body.map((item) => _fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<MealEntry> add(NewMealEntry entry) async {
    final response = await _post(_path, {
      'eatenAt': entry.eatenAt.toUtc().toIso8601String(),
      'mealType': entry.mealType.apiValue,
      'notes': MealNotesCodec.encode(entry.name, entry.portionG, entry.macros),
    });
    if (response.statusCode != 201) {
      throw AuthApiException(apiErrorMessage(response));
    }
    return _fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static MealEntry _fromJson(Map<String, dynamic> json) {
    final decoded = MealNotesCodec.decode(json['notes'] as String?);
    return MealEntry(
      id: json['id'] as String,
      mealType: MealType.fromApi(json['mealType'] as String),
      eatenAt: DateTime.parse(json['eatenAt'] as String),
      name: decoded.name,
      portionG: decoded.portionG,
      macros: decoded.macros,
    );
  }
}
