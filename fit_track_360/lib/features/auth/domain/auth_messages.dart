/// Flujo de autenticación en el que ocurrió un error. Decide el mensaje
/// genérico que se muestra cuando no hay uno más específico.
enum AuthFlow { login, register, recovery }

/// Textos de autenticación (es-MX). Fuente: `docs/copy/auth-strings.md`.
///
/// Son el único lugar con copy de auth: pantallas, ViewModels y el mapeo de
/// errores de Firebase/backend los reutilizan para no mostrar nunca el texto
/// técnico de un error (`e.message`, «Internal server error», «Token invalido»).
class AuthMessages {
  AuthMessages._();

  // Comunes
  static const emailLabel = 'Correo electrónico';
  static const emailHint = 'tu@correo.com';
  static const passwordLabel = 'Contraseña';
  static const invalidEmail = 'Ingresa un correo electrónico válido.';
  static const emailFormatHint = 'Usa el formato tu@correo.com';
  static const requiredFields = 'Completa los campos obligatorios.';
  static const requiredField = 'Completa este campo.';
  static const backToLogin = 'Volver a iniciar sesión';

  // Inicio de sesión
  static const loginTitle = 'Inicia sesión';
  static const loginSubtitle = 'Qué gusto verte de nuevo.';
  static const loginSubmit = 'Iniciar sesión';
  static const loginSubmitting = 'Iniciando sesión…';
  static const forgotPasswordLink = '¿Olvidaste tu contraseña?';
  static const registerPrompt = '¿Todavía no tienes una cuenta?';
  static const registerLink = 'Crear cuenta';
  static const invalidCredentials =
      'El correo o la contraseña no son correctos.';
  static const loginGeneric = 'No pudimos iniciar sesión. Inténtalo de nuevo.';

  // Registro
  static const registerTitle = 'Crea tu cuenta';
  static const registerSubtitle = 'Empieza a registrar tu progreso.';
  static const nameLabel = 'Nombre';
  static const nameHint = 'Tu nombre completo';
  static const usernameLabel = 'Usuario';
  static const usernameHint = 'Letras, números y guion bajo';
  static const passwordHint = 'Mínimo 8 caracteres';
  static const confirmPasswordLabel = 'Confirmar contraseña';
  static const confirmPasswordHint = 'Repite tu contraseña';
  static const registerSubmit = 'Crear cuenta';
  static const registerSubmitting = 'Creando cuenta…';
  static const privacyConsentLabel =
      'He leído el aviso de privacidad y acepto el tratamiento de mis datos '
      'personales descrito en él.';
  static const privacyNoticeLink = 'Consultar aviso de privacidad';
  static const loginPrompt = '¿Ya tienes una cuenta?';
  static const loginLink = 'Inicia sesión';
  static const invalidUsername =
      'El usuario debe tener entre 3 y 30 caracteres y solo puede incluir '
      'letras, números y guion bajo.';
  static const passwordTooShort =
      'La contraseña debe tener al menos 8 caracteres.';
  static const passwordMismatch = 'Las contraseñas no coinciden.';
  static const consentRequired =
      'Acepta el aviso de privacidad para crear tu cuenta.';
  static const consentRequiredGoogle =
      'Acepta el aviso de privacidad para continuar con Google.';
  static const emailAlreadyRegistered =
      'Ya existe una cuenta con este correo electrónico.';
  static const usernameAlreadyRegistered =
      'Ese nombre de usuario ya está en uso.';
  static const registerGeneric =
      'No pudimos crear tu cuenta. Inténtalo de nuevo.';

  // Recuperación de contraseña
  static const recoveryTitle = 'Recupera tu contraseña';
  static const recoveryInstructions =
      'Ingresa tu correo electrónico. Si existe una cuenta asociada, te '
      'enviaremos instrucciones para restablecer tu contraseña.';
  static const recoverySubmit = 'Enviar instrucciones';
  static const recoverySubmitting = 'Enviando…';
  static const recoverySuccess =
      'Si existe una cuenta asociada a ese correo, recibirás instrucciones '
      'para restablecer tu contraseña.';
  static const recoveryRequiredEmail = 'Ingresa tu correo electrónico.';
  static const recoveryGeneric =
      'No pudimos procesar tu solicitud. Inténtalo de nuevo.';

  // Errores de servicio (Firebase / backend)
  static const network =
      'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo '
      'de nuevo.';
  static const tooManyRequests =
      'Hiciste demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
  static const accountDisabled = 'Esta cuenta está deshabilitada.';
  static const accountExistsOtherMethod =
      'Ya existe una cuenta con este correo electrónico y otro método de '
      'acceso.';
  static const methodNotAllowed =
      'Este método de acceso no está disponible por ahora.';
  static const sessionInvalid =
      'No pudimos validar tu sesión. Inicia sesión de nuevo.';
  static const accountNotSynced =
      'No encontramos tu perfil de FitTrack360. Crea una cuenta para '
      'continuar.';
  static const accountAlreadyRegistered =
      'Esta cuenta ya está registrada. Inicia sesión.';
  static const authGeneric =
      'No pudimos completar la autenticación. Inténtalo de nuevo.';

  /// Mensaje genérico del [flow] para fallos técnicos sin texto específico.
  static String genericFor(AuthFlow flow) => switch (flow) {
    AuthFlow.login => loginGeneric,
    AuthFlow.register => registerGeneric,
    AuthFlow.recovery => recoveryGeneric,
  };

  /// Traduce un código de `FirebaseAuthException` a copy en español.
  ///
  /// Nunca devuelve el `message` técnico de Firebase: los códigos no
  /// conocidos caen en [authGeneric].
  static String forFirebaseCode(String code) => switch (code) {
    'email-already-in-use' => emailAlreadyRegistered,
    'invalid-email' => invalidEmail,
    'weak-password' => passwordTooShort,
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' ||
    'INVALID_LOGIN_CREDENTIALS' => invalidCredentials,
    'account-exists-with-different-credential' => accountExistsOtherMethod,
    'too-many-requests' => tooManyRequests,
    'network-request-failed' => network,
    'user-disabled' => accountDisabled,
    'operation-not-allowed' => methodNotAllowed,
    'user-token-expired' || 'invalid-user-token' => sessionInvalid,
    _ => authGeneric,
  };
}
