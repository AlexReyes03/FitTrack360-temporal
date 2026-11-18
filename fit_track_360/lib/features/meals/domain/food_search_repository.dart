import 'food_item.dart';

/// El proxy de USDA no respondió (404, error, cuota o timeout).
/// La vista ofrece captura manual.
class FoodSearchUnavailableException implements Exception {
  const FoodSearchUnavailableException();

  @override
  String toString() => 'Búsqueda de alimentos no disponible';
}

abstract interface class FoodSearchRepository {
  Future<List<FoodItem>> search(String query);
}
