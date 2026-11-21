import 'dart:io';

/// Falla si una pantalla crea un cliente HTTP real durante la prueba.
class RejectHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('No se esperaba crear un HttpClient en esta prueba.');
  }
}
