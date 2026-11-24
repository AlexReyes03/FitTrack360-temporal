import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../data/auth_api.dart';
import '../data/firebase_auth_service.dart';
import '../data/google_auth_gateway.dart';
import '../domain/auth_messages.dart';
import '../domain/auth_validators.dart';
import 'auth_error_messages.dart';

/// Versión del aviso de privacidad que acepta el registro.
const privacyNoticeVersion = '2';

/// Base de los ViewModels de auth: estado del envío como [AsyncState].
///
/// - [AsyncEmpty]: formulario en reposo.
/// - [AsyncLoading]: envío en curso (el CTA muestra el indicador).
/// - [AsyncData]: sesión o solicitud completada.
/// - [AsyncError]: el `error` es el mensaje en español listo para la UI.
abstract class AuthFormViewModel<T> extends ChangeNotifier {
  AuthFormViewModel(this.flow);

  final AuthFlow flow;

  AsyncState<T> _state = const AsyncEmpty();
  bool _googleLoading = false;
  bool _disposed = false;

  AsyncState<T> get state => _state;
  bool get isSubmitting => _state.isLoading;
  bool get isGoogleLoading => _googleLoading;
  bool get isBusy => isSubmitting || _googleLoading;

  /// Mensaje de error visible bajo el CTA, o `null`.
  String? get errorMessage => switch (_state) {
    AsyncError<T>(:final error) => error.toString(),
    _ => null,
  };

  @protected
  void setState(AsyncState<T> value) {
    _state = value;
    _notify();
  }

  @protected
  void showError(String message) => setState(AsyncError<T>(message));

  @protected
  void setGoogleLoading(bool value) {
    _googleLoading = value;
    _notify();
  }

  /// Ejecuta [action] con estado de carga y traduce cualquier fallo.
  @protected
  Future<bool> run(Future<T> Function() action) async {
    if (isBusy) return false;
    setState(const AsyncLoading());
    try {
      final result = await action();
      setState(AsyncData<T>(result));
      return true;
    } catch (error) {
      showError(describeAuthError(error, flow));
      return false;
    }
  }

  /// Flujo de Google con su propio indicador; cancelar no es un error.
  @protected
  Future<bool> runGoogle(Future<T> Function() action) async {
    if (isBusy) return false;
    setState(const AsyncEmpty());
    setGoogleLoading(true);
    try {
      final result = await action();
      _googleLoading = false;
      setState(AsyncData<T>(result));
      return true;
    } on GoogleSignInCancelledException {
      setGoogleLoading(false);
      return false;
    } catch (error) {
      _googleLoading = false;
      showError(describeAuthError(error, flow));
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// ViewModel de «Inicia sesión».
class LoginViewModel extends AuthFormViewModel<AuthUser> {
  /// [auth] se resuelve de forma perezosa: sin inyección se usa
  /// [FirebaseAuthService] solo al enviar (las pruebas no inicializan Firebase).
  LoginViewModel({FirebaseAuthService? auth})
    : _injectedAuth = auth,
      super(AuthFlow.login);

  final FirebaseAuthService? _injectedAuth;
  late final FirebaseAuthService _auth = _injectedAuth ?? FirebaseAuthService();

  /// La contraseña se envía tal cual (sin recortar), igual que en registro.
  Future<bool> submit({required String email, required String password}) {
    final issue = AuthValidators.validateLogin(
      email: email,
      password: password,
    );
    if (issue != null) {
      showError(issue);
      return Future.value(false);
    }
    return run(() => _auth.login(email: email.trim(), password: password));
  }

  Future<bool> submitGoogle() =>
      runGoogle(() => _auth.loginWithGoogle(allowAutoRegister: false));
}

/// ViewModel de «Crea tu cuenta».
class RegisterViewModel extends AuthFormViewModel<AuthUser> {
  /// [auth] se resuelve de forma perezosa: sin inyección se usa
  /// [FirebaseAuthService] solo al enviar (las pruebas no inicializan Firebase).
  RegisterViewModel({FirebaseAuthService? auth})
    : _injectedAuth = auth,
      super(AuthFlow.register);

  final FirebaseAuthService? _injectedAuth;
  late final FirebaseAuthService _auth = _injectedAuth ?? FirebaseAuthService();

  bool _privacyConsent = false;
  bool _submitAttempted = false;
  Set<RegisterField> _missingFields = const {};

  bool get privacyConsent => _privacyConsent;

  /// Campos obligatorios vacíos del último intento de envío.
  Set<RegisterField> get missingFields => _missingFields;

  /// Si el último intento falló por falta de consentimiento.
  bool get consentMissing => _submitAttempted && !_privacyConsent;

  void setPrivacyConsent(bool value) {
    _privacyConsent = value;
    final consentError =
        errorMessage == AuthMessages.consentRequired ||
        errorMessage == AuthMessages.consentRequiredGoogle;
    setState(value && consentError ? const AsyncEmpty() : state);
  }

  /// Valida al tocar el CTA y explica por qué no avanza (campos requeridos,
  /// formato o consentimiento) en lugar de dejar el botón deshabilitado.
  Future<bool> submit(RegisterForm form) {
    _submitAttempted = true;
    _missingFields = form.missingFields;
    final issue = AuthValidators.validateRegistration(
      form,
      privacyConsent: _privacyConsent,
    );
    if (issue != null) {
      showError(issue);
      return Future.value(false);
    }
    return run(
      () => _auth.register(
        username: form.username.trim(),
        email: form.email.trim(),
        password: form.password,
        displayName: form.displayName.trim(),
        privacyConsent: true,
        privacyNoticeVersion: privacyNoticeVersion,
      ),
    );
  }

  /// Limpia el error inline de un campo cuando el usuario lo completa.
  void fieldChanged(RegisterField field, String value) {
    if (!_missingFields.contains(field)) return;
    final empty =
        field == RegisterField.password ||
            field == RegisterField.confirmPassword
        ? value.isEmpty
        : value.trim().isEmpty;
    if (empty) return;
    _missingFields = {..._missingFields}..remove(field);
    setState(state);
  }

  Future<bool> submitGoogle() {
    if (isBusy) return Future.value(false);
    if (!_privacyConsent) {
      _submitAttempted = true;
      showError(AuthMessages.consentRequiredGoogle);
      return Future.value(false);
    }
    return runGoogle(
      () => _auth.loginWithGoogle(
        allowAutoRegister: true,
        privacyConsent: true,
        privacyNoticeVersion: privacyNoticeVersion,
      ),
    );
  }
}

/// ViewModel de «Recupera tu contraseña». No revela si el correo existe.
class ForgotPasswordViewModel extends AuthFormViewModel<void> {
  /// [auth] se resuelve de forma perezosa: sin inyección se usa
  /// [FirebaseAuthService] solo al enviar (las pruebas no inicializan Firebase).
  ForgotPasswordViewModel({FirebaseAuthService? auth})
    : _injectedAuth = auth,
      super(AuthFlow.recovery);

  final FirebaseAuthService? _injectedAuth;
  late final FirebaseAuthService _auth = _injectedAuth ?? FirebaseAuthService();

  /// Se envió la solicitud: mostrar [AuthMessages.recoverySuccess].
  bool get sent => state is AsyncData<void>;

  Future<bool> submit(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      showError(AuthMessages.recoveryRequiredEmail);
      return Future.value(false);
    }
    if (!AuthValidators.isValidEmail(trimmed)) {
      showError(AuthMessages.invalidEmail);
      return Future.value(false);
    }
    return run(() => _auth.sendPasswordResetEmail(email: trimmed));
  }
}
