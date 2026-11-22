import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Mensaje cuando el SDK nativo no puede iniciar Google (cliente OAuth,
/// SHA-1 o plist faltantes, DEVELOPER_ERROR, etc.).
const googleSignInUnavailableMessage =
    'Inicio con Google no disponible en este dispositivo por ahora. Usa tu correo y contraseña.';

/// Mensaje cuando Google no responde por falta de red.
const googleSignInNetworkMessage =
    'No se pudo conectar con Google. Revisa tu conexion e intenta de nuevo.';

/// Resultado del picker de Google (antes de Firebase credential).
class GoogleAuthTokens {
  const GoogleAuthTokens({required this.idToken, this.email, this.displayName});

  /// Suficiente para `GoogleAuthProvider.credential` (Firebase no exige
  /// access token; en google_sign_in 7.x requiere un paso de autorizacion).
  final String idToken;
  final String? email;
  final String? displayName;
}

/// El usuario cerro el sheet de Google sin elegir cuenta.
class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();

  @override
  String toString() => 'Inicio de sesion con Google cancelado';
}

/// Abstraccion de `google_sign_in` (inyectable en tests).
abstract class GoogleAuthGateway {
  Future<GoogleAuthTokens> signIn();

  Future<void> signOut();
}

/// Gateway real sobre `google_sign_in` 7.x.
///
/// [serverClientId] = Web client ID de Firebase (Android lo necesita para
/// emitir idToken). `GoogleSignIn.instance` es singleton y `initialize` debe
/// llamarse una sola vez por proceso, aunque se creen varios gateways.
class GoogleSignInGateway implements GoogleAuthGateway {
  GoogleSignInGateway({GoogleSignIn? googleSignIn, String? serverClientId})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
      _serverClientId = serverClientId?.isEmpty == true ? null : serverClientId;

  static const _scopes = ['email', 'profile'];

  /// Inicializaciones en curso/completadas por instancia de [GoogleSignIn].
  static final Expando<Future<void>> _initializations = Expando();

  final GoogleSignIn _googleSignIn;
  final String? _serverClientId;

  Future<void> _ensureInitialized() {
    final existing = _initializations[_googleSignIn];
    if (existing != null) return existing;
    final future = _googleSignIn
        .initialize(serverClientId: _serverClientId)
        .catchError((Object error) {
          // Permite reintentar si la configuracion falla.
          _initializations[_googleSignIn] = null;
          throw error;
        });
    _initializations[_googleSignIn] = future;
    return future;
  }

  @override
  Future<GoogleAuthTokens> signIn() async {
    try {
      await _ensureInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const GoogleSignInUnavailableException(
          code: 'authenticate_unsupported',
        );
      }
      final account = await _googleSignIn.authenticate(scopeHint: _scopes);
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInUnavailableException(code: 'missing_id_token');
      }
      return GoogleAuthTokens(
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      throw mapGoogleSignInException(e);
    } on PlatformException catch (e) {
      throw GoogleSignInUnavailableException(code: e.code);
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
  }
}

/// Traduce errores de `google_sign_in` 7.x a errores de dominio.
///
/// `canceled` es una cancelacion del usuario (no se muestra error). El plugin
/// no tiene codigo de red: llega como `unknownError` y solo la descripcion
/// tecnica lo distingue.
Exception mapGoogleSignInException(GoogleSignInException e) {
  switch (e.code) {
    case GoogleSignInExceptionCode.canceled:
      return const GoogleSignInCancelledException();
    case GoogleSignInExceptionCode.unknownError
        when (e.description ?? '').toLowerCase().contains('network'):
      return const GoogleSignInNetworkException();
    default:
      return GoogleSignInUnavailableException(code: e.code.name);
  }
}

/// Error controlado de Google Sign-In con mensaje listo para la UI.
abstract class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure({required this.code});

  /// Codigo tecnico de origen (p. ej. `sign_in_failed`), util para soporte.
  final String code;

  String get message;

  @override
  String toString() => message;
}

/// Google no esta disponible en este dispositivo (configuracion OAuth
/// incompleta, DEVELOPER_ERROR, tokens vacios u otro error nativo).
class GoogleSignInUnavailableException extends GoogleSignInFailure {
  const GoogleSignInUnavailableException({required super.code});

  @override
  String get message => googleSignInUnavailableMessage;
}

/// Google no respondio por falta de red.
class GoogleSignInNetworkException extends GoogleSignInFailure {
  const GoogleSignInNetworkException({super.code = 'network_error'});

  @override
  String get message => googleSignInNetworkMessage;
}
