/// Resultado de una operacion asincrona con tres estados (T1 / nivelacion T3).
///
/// Al ser [sealed], un `switch` sin `default` es exhaustivo en Dart 3.
sealed class Resultado<T> {
  const Resultado();
}

/// La operacion esta en curso.
final class Cargando<T> extends Resultado<T> {
  const Cargando();
}

/// La operacion termino con un valor.
final class Exito<T> extends Resultado<T> {
  const Exito(this.dato);

  final T dato;
}

/// La operacion fallo. [mensaje] es legible para la UI (sin stack trace).
final class Error<T> extends Resultado<T> {
  const Error(this.mensaje);

  final String mensaje;
}
