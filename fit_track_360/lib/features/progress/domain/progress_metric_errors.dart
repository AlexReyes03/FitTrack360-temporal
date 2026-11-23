/// Base de los errores de la API de métricas corporales.
abstract class ProgressMetricException implements Exception {
  const ProgressMetricException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// El cuerpo o los parámetros no pasaron la validación del API (400).
class ProgressMetricValidationException extends ProgressMetricException {
  const ProgressMetricValidationException(super.message);
}

/// Métrica ajena o inexistente. Regla S4: el mensaje no filtra si existe.
class ProgressMetricNotFoundException extends ProgressMetricException {
  const ProgressMetricNotFoundException([
    super.message = 'Métrica no disponible',
  ]);
}

/// Fallo del servidor o de red que no corresponde a validación ni a 404.
class ProgressMetricRequestException extends ProgressMetricException {
  const ProgressMetricRequestException(super.message);
}
