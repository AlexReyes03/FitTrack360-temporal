import 'auth_messages.dart';

/// Reglas de validación compartidas por las pantallas de autenticación.
///
/// Las contraseñas nunca se recortan (ni en registro ni en inicio de
/// sesión): lo que el usuario escribe es exactamente lo que se envía a
/// Firebase. Solo se recortan correo, usuario y nombre.
class AuthValidators {
  AuthValidators._();

  /// Formato básico de correo: texto, arroba, dominio y extensión.
  static final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Regla vigente del RegisterDto: 3 a 30 caracteres, `[a-zA-Z0-9_]`.
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  static const int minPasswordLength = 8;

  static bool isValidEmail(String value) => emailPattern.hasMatch(value.trim());

  /// Valida el formulario de inicio de sesión. Devuelve el motivo por el que
  /// no se puede enviar o `null` si es válido.
  static String? validateLogin({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty || password.isEmpty) {
      return AuthMessages.requiredFields;
    }
    if (!isValidEmail(email)) return AuthMessages.invalidEmail;
    return null;
  }

  /// Valida el formulario de registro, incluido el consentimiento del aviso
  /// de privacidad. Devuelve el motivo o `null` si es válido.
  static String? validateRegistration(
    RegisterForm form, {
    required bool privacyConsent,
  }) {
    if (form.missingFields.isNotEmpty) return AuthMessages.requiredFields;
    if (!usernamePattern.hasMatch(form.username.trim())) {
      return AuthMessages.invalidUsername;
    }
    if (!isValidEmail(form.email)) return AuthMessages.invalidEmail;
    if (form.password.length < minPasswordLength) {
      return AuthMessages.passwordTooShort;
    }
    if (form.password != form.confirmPassword) {
      return AuthMessages.passwordMismatch;
    }
    if (!privacyConsent) return AuthMessages.consentRequired;
    return null;
  }
}

/// Campos del formulario de registro.
enum RegisterField { displayName, username, email, password, confirmPassword }

/// Datos capturados en el registro, tal como los escribió el usuario.
class RegisterForm {
  final String displayName;
  final String username;
  final String email;
  final String password;
  final String confirmPassword;

  const RegisterForm({
    required this.displayName,
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  /// Campos obligatorios vacíos (correo, usuario y nombre se recortan; las
  /// contraseñas no).
  Set<RegisterField> get missingFields => {
    if (displayName.trim().isEmpty) RegisterField.displayName,
    if (username.trim().isEmpty) RegisterField.username,
    if (email.trim().isEmpty) RegisterField.email,
    if (password.isEmpty) RegisterField.password,
    if (confirmPassword.isEmpty) RegisterField.confirmPassword,
  };
}
