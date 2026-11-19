import 'package:google_sign_in/google_sign_in.dart';

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
      throw const AuthGoogleTokensMissingException();
    }
    return GoogleAuthTokens(
      idToken: idToken,
      accessToken: accessToken,
      email: account.email,
      displayName: account.displayName,
    );
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}

class AuthGoogleTokensMissingException implements Exception {
  const AuthGoogleTokensMissingException();

  @override
  String toString() =>
      'Google no devolvio tokens. Revisa el Web client ID (GOOGLE_WEB_CLIENT_ID) y SHA-1 en Firebase Console.';
}
