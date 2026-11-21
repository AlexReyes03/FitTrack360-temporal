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
  const GoogleAuthTokens({
    required this.idToken,
    required this.accessToken,
    this.email,
    this.displayName,
  });

  final String idToken;
  final String accessToken;
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

/// Gateway real. [serverClientId] = Web client ID de Firebase (Android idToken).
class GoogleSignInGateway implements GoogleAuthGateway {
  GoogleSignInGateway({GoogleSignIn? googleSignIn, String? serverClientId})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: const ['email', 'profile'],
            serverClientId: serverClientId?.isEmpty == true
                ? null
                : serverClientId,
          );

  final GoogleSignIn _googleSignIn;

  @override
  Future<GoogleAuthTokens> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const GoogleSignInCancelledException();
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null ||
          idToken.isEmpty ||
          accessToken == null ||
          accessToken.isEmpty) {
        throw const GoogleSignInUnavailableException(code: 'missing_tokens');
      }
      return GoogleAuthTokens(
        idToken: idToken,
        accessToken: accessToken,
        email: account.email,
        displayName: account.displayName,
      );
    } on PlatformException catch (e) {
      throw mapGoogleSignInPlatformException(e);
    }
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}

/// Traduce errores nativos de `google_sign_in` a errores de dominio.
///
/// `sign_in_canceled` es una cancelacion del usuario (no se muestra error).
Exception mapGoogleSignInPlatformException(PlatformException e) {
  switch (e.code) {
    case GoogleSignIn.kSignInCanceledError:
      return const GoogleSignInCancelledException();
    case GoogleSignIn.kNetworkError:
      return const GoogleSignInNetworkException();
    default:
      return GoogleSignInUnavailableException(code: e.code);
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
  const GoogleSignInNetworkException({super.code = GoogleSignIn.kNetworkError});

  @override
  String get message => googleSignInNetworkMessage;
}
