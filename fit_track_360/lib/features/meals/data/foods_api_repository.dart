import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../domain/food_item.dart';
import '../domain/food_search_repository.dart';
import '../domain/macros.dart';
import 'meals_api_repository.dart';

/// FoodSearchRepository contra el proxy propio (`fit_track_api/src/foods/`,
/// PR #153): `GET /api/v1/foods/search?q=` → arreglo de FoodItemDto
/// `{fdcId: number, description, name, servingG: 100, kcal, proteinG,
/// carbsG, fatG, brandOwner?}` por 100 g (también acepta `{items}`).
/// Nunca llama a USDA directo. Cualquier respuesta distinta de 200 (400 por
/// `q` vacío o > 120, 503 USDA_UNAVAILABLE, otros 4xx/5xx), un payload
/// inesperado o un timeout se traducen en [FoodSearchUnavailableException];
/// [SessionExpiredException] se propaga para redirigir a `/login`.
class FoodsApiRepository implements FoodSearchRepository {
  FoodsApiRepository({
    required this._get,
    this.timeout = const Duration(seconds: 5),
  });

  factory FoodsApiRepository.fromClient(ApiClient client) =>
      FoodsApiRepository(get: client.get);

  final GetRequest _get;
  final Duration timeout;

  @override
  Future<List<FoodItem>> search(String query) async {
    final path = '/api/v1/foods/search?q=${Uri.encodeQueryComponent(query)}';
    try {
      final response = await _get(path).timeout(timeout);
      if (response.statusCode != 200) {
        throw const FoodSearchUnavailableException();
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final items = body is Map<String, dynamic> ? body['items'] : body;
      if (items is! List) throw const FoodSearchUnavailableException();
      return items
          .map((item) => _fromJson(item as Map<String, dynamic>))
          .toList();
    } on SessionExpiredException {
      rethrow;
    } on FoodSearchUnavailableException {
      rethrow;
    } catch (_) {
      throw const FoodSearchUnavailableException();
    }
  }

  static FoodItem _fromJson(Map<String, dynamic> json) {
    double n(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return FoodItem(
      fdcId: (json['fdcId'] as num?)?.toInt(),
      name: (json['description'] ?? json['name'] ?? 'Sin nombre') as String,
      baseServingG: (json['servingG'] as num?)?.toDouble() ?? 100,
      macros: Macros(
        kcal: n('kcal'),
        proteinG: n('proteinG'),
        carbsG: n('carbsG'),
        fatG: n('fatG'),
      ),
    );
  }
}
