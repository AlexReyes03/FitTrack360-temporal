import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../domain/local_day.dart';
import '../domain/macros.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_item.dart';
import '../domain/meal_type.dart';
import '../domain/meals_repository.dart';
import 'meal_notes_codec.dart';

typedef GetRequest = Future<http.Response> Function(String path);
typedef PostRequest = Future<http.Response> Function(
  String path,
  Map<String, dynamic> body,
);
typedef PatchRequest = Future<http.Response> Function(
  String path,
  Map<String, dynamic> body,
);
typedef DeleteRequest = Future<http.Response> Function(String path);

/// MealsRepository contra el contrato real de `fit_track_api/src/meals/`:
/// - `POST /api/v1/meals` con CreateMealDto `{eatenAt, mealType, items}`;
///   cada item es CreateMealItemDto `{name, fdcId?, servingG, kcal,
///   proteinG, carbsG, fatG}` (fdcId es texto). No envía notes ni photoId.
/// - `GET /api/v1/meals` devuelve MealResponseDto[] con `items` tipados.
///   El API no filtra por día; el dominio filtra al día local.
/// - `GET /api/v1/meals/summary` con DailySummaryQueryDto. El API toma
///   `date` como día UTC, así que además se envían `from`/`to` con los
///   límites del día local; `date` queda como la fecha local explícita.
/// - `PATCH /api/v1/meals/:id` reemplaza todos los `items` enviados.
/// - `DELETE /api/v1/meals/:id` elimina la comida completa.
///
/// [SessionExpiredException] de [ApiClient] se propaga sin envolver.
class MealsApiRepository implements MealsRepository {
  MealsApiRepository({
    required this._get,
    required this._post,
    required this._patch,
    required this._delete,
  });

  factory MealsApiRepository.fromClient(ApiClient client) => MealsApiRepository(
    get: client.get,
    post: (path, body) => client.post(path, body: body),
    patch: (path, body) => client.patch(path, body: body),
    delete: client.delete,
  );

  final GetRequest _get;
  final PostRequest _post;
  final PatchRequest _patch;
  final DeleteRequest _delete;

  static const _path = '/api/v1/meals';

  @override
  Future<List<MealEntry>> list() async {
    final body = _decode(await _get(_path), 200);
    if (body is! List) throw const AuthApiException('No se pudo conectar');
    return body.map((item) => _fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<MealEntry> add(NewMealEntry entry) async {
    final response = await _post(_path, {
      'eatenAt': entry.eatenAt.toUtc().toIso8601String(),
      'mealType': entry.mealType.apiValue,
      'items': [_itemToJson(entry.item)],
    });
    final body = _decode(response, 201);
    if (body is! Map<String, dynamic>) {
      throw const AuthApiException('No se pudo conectar');
    }
    return _fromJson(body);
  }

  @override
  Future<MealEntry> update(String mealId, List<MealItem> items) async {
    final response = await _patch('$_path/$mealId', {
      'items': items.map(_itemToJson).toList(),
    });
    if (response.statusCode == 404) throw const MealNotFoundException();
    final body = _decode(response, 200);
    if (body is! Map<String, dynamic>) {
      throw const AuthApiException('No se pudo conectar');
    }
    return _fromJson(body);
  }

  @override
  Future<void> delete(String mealId) async {
    final response = await _delete('$_path/$mealId');
    if (response.statusCode == 404) throw const MealNotFoundException();
    if (response.statusCode != 204) {
      throw AuthApiException(apiErrorMessage(response));
    }
  }

  @override
  Future<Macros> dayTotals(LocalDay day) async {
    final query = Uri(
      queryParameters: {
        'date': day.key,
        'from': day.start.toUtc().toIso8601String(),
        'to': day.end.toUtc().toIso8601String(),
      },
    ).query;
    final body = _decode(await _get('$_path/summary?$query'), 200);
    final totals = body is Map<String, dynamic> ? body['totals'] : null;
    if (totals is! Map<String, dynamic>) {
      throw const AuthApiException('No se pudo conectar');
    }
    return _macros(totals);
  }

  static Object? _decode(http.Response response, int expectedStatus) {
    if (response.statusCode != expectedStatus) {
      throw AuthApiException(apiErrorMessage(response));
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static MealEntry _fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .map((item) => _itemFromJson(item as Map<String, dynamic>))
              .toList()
        : <MealItem>[];
    final notes = (json['notes'] as String?)?.trim() ?? '';
    final legacy = items.isEmpty && notes.isNotEmpty;
    if (legacy) {
      final decoded = MealNotesCodec.decode(notes);
      items.add(
        MealItem(
          name: decoded.name,
          servingG: decoded.portionG,
          macros: decoded.macros,
        ),
      );
    }
    return MealEntry(
      id: json['id'] as String,
      mealType: MealType.fromApi(json['mealType'] as String),
      eatenAt: DateTime.parse(json['eatenAt'] as String),
      items: items,
      isLegacy: legacy,
    );
  }

  static MealItem _itemFromJson(Map<String, dynamic> json) => MealItem(
    id: json['id'] as String?,
    fdcId: json['fdcId'] as String?,
    name: json['name'] as String,
    servingG: (json['servingG'] as num).toDouble(),
    macros: _macros(json),
  );

  /// Campos de CreateMealItemDto; el `id` no se envía.
  static Map<String, dynamic> _itemToJson(MealItem item) => {
    'name': item.name.trim(),
    if (item.fdcId != null) 'fdcId': item.fdcId,
    'servingG': item.servingG,
    'kcal': item.macros.kcal,
    'proteinG': item.macros.proteinG,
    'carbsG': item.macros.carbsG,
    'fatG': item.macros.fatG,
  };

  static Macros _macros(Map<String, dynamic> json) {
    double n(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return Macros(
      kcal: n('kcal'),
      proteinG: n('proteinG'),
      carbsG: n('carbsG'),
      fatG: n('fatG'),
    );
  }
}
