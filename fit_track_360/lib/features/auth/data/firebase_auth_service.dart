import 'package:firebase_auth/firebase_auth.dart';

import 'auth_api.dart';
import 'google_auth_gateway.dart';

/// Client ID web de Firebase (OAuth). Se pasa con
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=...` (no es un secret de service account).
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// Auth remoto: Firebase Auth + sync Nest (AUTH-01 / AUTH-02 Google).
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleAuthGateway? googleAuth})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleAuth =
          googleAuth ??
          GoogleSignInGateway(
            serverClientId: googleWebClientId.isEmpty
                ? null
                : googleWebClientId,
          );

  final FirebaseAuth _auth;
  final GoogleAuthGateway _googleAuth;

  User? get currentUser => _auth.currentUser;

  Future<String> _requireIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthApiException('Sesion invalida');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw const AuthApiException('Sesion invalida');
    }
    return token;
  }

  Future<AuthUser> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required bool privacyConsent,
    required String privacyNoticeVersion,
  }) async {
    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthApiException(_mapFirebaseError(e));
    }

    try {
      await credential.user?.updateDisplayName(displayName);
      final idToken = await _requireIdToken(forceRefresh: true);
      return await syncRegister(
        idToken: idToken,
        username: username,
        displayName: displayName,
        privacyConsent: privacyConsent,
        privacyNoticeVersion: privacyNoticeVersion,
      );
    } catch (error) {
      // Evita huérfanos Firebase sin fila en Postgres.
      try {
        await credential.user?.delete();
      } catch (_) {}
      try {
        await _auth.signOut();
      } catch (_) {}
      rethrow;
    }
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthApiException(_mapFirebaseError(e));
    }
    final idToken = await _requireIdToken(forceRefresh: true);
    return syncSession(idToken: idToken);
  }

  /// Login / alta con Google (AUTH-02).
  ///
  /// [allowAutoRegister]: en registro (con aviso de privacidad aceptado) crea
  /// el User Nest si aún no existe. En login, si no hay User, deja un mensaje
  /// controlado sin inventar consentimiento.
  ///
  /// Cancelar el sheet de Google → [GoogleSignInCancelledException] (no fatal).
  Future<AuthUser> loginWithGoogle({
    bool allowAutoRegister = false,
    bool privacyConsent = false,
    String privacyNoticeVersion = '2',
  }) async {
    GoogleAuthTokens googleTokens;
    try {
      googleTokens = await _googleAuth.signIn();
    } on GoogleSignInCancelledException {
      rethrow;
    } on AuthGoogleTokensMissingException catch (e) {
      throw AuthApiException(e.toString());
    }

    try {
      final credential = GoogleAuthProvider.credential(
        idToken: googleTokens.idToken,
        accessToken: googleTokens.accessToken,
      );
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      await _safeGoogleSignOut();
      throw AuthApiException(_mapFirebaseError(e));
    }

    final idToken = await _requireIdToken(forceRefresh: true);
    try {
      return await syncSession(idToken: idToken);
    } on AuthApiException catch (error) {
      final message = error.message;
      final needsRegister =
          message.contains('Usuario no sincronizado') ||
          message.contains('no sincronizado');
      final emailTaken = message.contains('otra cuenta');

      if (emailTaken) {
        await _rollbackGoogleSession();
        throw const AuthApiException(
          'El correo ya esta registrado con otra cuenta',
        );
      }

      if (!needsRegister) {
        await _rollbackGoogleSession();
        rethrow;
      }

      if (!allowAutoRegister || !privacyConsent) {
        await _rollbackGoogleSession();
        throw const AuthApiException(
          'No hay cuenta vinculada. Usa Crear cuenta, acepta el aviso de privacidad y continua con Google.',
        );
      }

      final email =
          googleTokens.email ??
          _auth.currentUser?.email ??
          'user@fittrack.local';
      final displayName =
          (googleTokens.displayName?.trim().isNotEmpty == true
              ? googleTokens.displayName!.trim()
              : null) ??
          _auth.currentUser?.displayName?.trim() ??
          email.split('@').first;

      return _registerGoogleProfile(
        idToken: idToken,
        email: email,
        displayName: displayName,
        privacyConsent: privacyConsent,
        privacyNoticeVersion: privacyNoticeVersion,
      );
    }
  }

  Future<AuthUser> _registerGoogleProfile({
    required String idToken,
    required String email,
    required String displayName,
    required bool privacyConsent,
    required String privacyNoticeVersion,
  }) async {
    var username = _usernameFromEmail(email);
    AuthApiException? lastConflict;

    for (var attempt = 0; attempt < 4; attempt++) {
      final candidate = attempt == 0
          ? username
          : _withSuffix(username, attempt);
      try {
        return await syncRegister(
          idToken: idToken,
          username: candidate,
          displayName: displayName.length > 80
              ? displayName.substring(0, 80)
              : displayName,
          privacyConsent: privacyConsent,
          privacyNoticeVersion: privacyNoticeVersion,
        );
      } on AuthApiException catch (error) {
        if (error.message.contains('correo ya esta registrado')) {
          await _rollbackGoogleSession();
          throw const AuthApiException(
            'El correo ya esta registrado con otra cuenta',
          );
        }
        if (error.message.contains('usuario ya esta registrado') ||
            error.message.contains('username')) {
          lastConflict = error;
          continue;
        }
        await _rollbackGoogleSession();
        rethrow;
      }
    }

    await _rollbackGoogleSession();
    throw lastConflict ??
        const AuthApiException('No se pudo completar el registro con Google');
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Misma UX: no enumerar si el correo existe.
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return;
      }
      throw AuthApiException(_mapFirebaseError(e));
    }
  }

  Future<void> logout() async {
    String? idToken;
    try {
      idToken = await _auth.currentUser?.getIdToken();
      if (idToken != null) {
        await revokeRemoteSession(idToken: idToken);
      }
    } catch (_) {
      // La sesión local se limpia igual.
    } finally {
      await _safeGoogleSignOut();
      await _auth.signOut();
    }
  }

  Future<void> _rollbackGoogleSession() async {
    await _safeGoogleSignOut();
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<void> _safeGoogleSignOut() async {
    try {
      await _googleAuth.signOut();
    } catch (_) {}
  }

  static String _usernameFromEmail(String email) {
    final local = email.split('@').first.toLowerCase();
    var cleaned = local.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'_+'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'^_|_$'), '');
    if (cleaned.length < 3) {
      cleaned = 'usr$cleaned';
    }
    if (cleaned.length > 24) {
      cleaned = cleaned.substring(0, 24);
    }
    return cleaned;
  }

  static String _withSuffix(String base, int attempt) {
    final suffix = '_${attempt + 1}';
    final maxBase = 30 - suffix.length;
    final trimmed = base.length > maxBase ? base.substring(0, maxBase) : base;
    return '$trimmed$suffix';
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'El correo ya esta registrado';
      case 'invalid-email':
        return 'Correo invalido';
      case 'weak-password':
        return 'La contraseña debe tener al menos 8 caracteres';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Credenciales incorrectas';
      case 'account-exists-with-different-credential':
        return 'El correo ya esta registrado con otro metodo de acceso';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta mas tarde';
      case 'network-request-failed':
        return 'No se pudo conectar';
      case 'user-disabled':
        return 'Esta cuenta esta deshabilitada';
      default:
        return e.message ?? 'No se pudo completar la autenticacion';
    }
  }
}
