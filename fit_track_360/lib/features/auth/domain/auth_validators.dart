/// Reglas de validacion compartidas por las pantallas de autenticacion.
class AuthValidators {
  AuthValidators._();

  /// Formato basico de correo: texto, arroba, dominio y extension.
  static final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool isValidEmail(String value) => emailPattern.hasMatch(value.trim());
}
