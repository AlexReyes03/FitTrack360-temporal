import '../domain/comida_demo.dart';

/// Repositorio falso para la nivelacion T3.
///
/// Simula latencia de red. La primera llamada falla; la segunda (y siguientes)
/// devuelven al menos cinco comidas de ejemplo.
class ComidasRepositorioFalso {
  int _llamadas = 0;

  Future<List<ComidaDemo>> obtener() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    _llamadas++;
    if (_llamadas == 1) {
      throw Exception('Sin conexion');
    }
    return const [
      ComidaDemo(nombre: 'Avena con fruta', tipo: 'Desayuno', calorias: 320),
      ComidaDemo(nombre: 'Pollo a la plancha', tipo: 'Comida', calorias: 450),
      ComidaDemo(nombre: 'Ensalada verde', tipo: 'Comida', calorias: 180),
      ComidaDemo(nombre: 'Yogur griego', tipo: 'Snack', calorias: 150),
      ComidaDemo(nombre: 'Salmon al horno', tipo: 'Cena', calorias: 520),
      ComidaDemo(nombre: 'Batido de proteina', tipo: 'Snack', calorias: 210),
    ];
  }
}
