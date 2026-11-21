import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_api.dart';
import 'google_auth_gateway.dart';

/// Client ID web de Firebase (OAuth). Se pasa con
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=...` (no es un secret de service account).
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// Login con Google sin User en Nest y sin consentimiento de privacidad.
const googleAccountNotLinkedMessage =
    'No hay cuenta vinculada. Usa Crear cuenta, acepta el aviso de privacidad y continua con Google.';

/// El correo de Google ya pertenece a otra cuenta de FitTrack360.
const googleEmailTakenMessage = 'El correo ya esta registrado con otra cuenta';

/// Intentos de username con sufijo aleatorio tras la primera colision.
const googleUsernameRetryAttempts = 5;

typedef SyncSessionFn = Future<AuthUser> Function({required String idToken});

typedef SyncRegisterFn = Future<AuthUser> Function({
  required String idToken,
  required String username,
  required String displayName,
  required bool privacyConsent,
  required String privacyNoticeVersion,
});

/// Auth remoto: Firebase Auth + sync Nest (AUTH-01 / AUTH-02 Google).
class FirebaseAuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    GoogleAuthGateway? googleAuth,
    SyncSessionFn? syncSessionFn,
    SyncRegisterFn? syncRegisterFn,
    Random? random,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleAuth =
           googleAuth ??
           GoogleSignInGateway(
             serverClientId: googleWebClientId.isEmpty
                 ? null
                 : googleWebClientId,
           ),
       _syncSession = syncSessionFn ?? syncSession,
       _syncRegister = syncRegisterFn ?? syncRegister,
       _random = random ?? Random();

  final FirebaseAuth _auth;
  final GoogleAuthGateway _googleAuth;
  final SyncSessionFn _syncSession;
  final SyncRegisterFn _syncRegister;
  final Random _random;

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
      return await _syncRegister(
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
    return _syncSession(idToken: idToken);
  }

  /// Login / alta con Google (AUTH-02).
  ///
  /// [allowAutoRegister]: en registro (con aviso de privacidad aceptado) crea
  /// el User Nest si aún no existe. En login, si no hay User, deja un mensaje
  /// controlado sin inventar consentimiento.
  ///
  /// Cancelar el sheet de Google → [GoogleSignInCancelledException] (no fatal).
  /// Si algo falla tras crear el usuario Firebase en este flujo, se borra
  /// (igual que AUTH-01) para no dejar huérfanos sin fila en Postgres.
  Future<AuthUser> loginWithGoogle({
    bool allowAutoRegister = false,
    bool privacyConsent = false,
    String privacyNoticeVersion = '2',
  }) async {
    GoogleAuthTokens googleTokens;
    try {
      googleTokens = await _googleAuth.signIn();
    } on GoogleSignInFailure catch (e) {
      throw AuthApiException(e.message);
    }

    UserCredential credential;
    try {
      credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleTokens.idToken),
      );
    } on FirebaseAuthException catch (e) {
      await _safeGoogleSignOut();
      throw AuthApiException(_mapFirebaseError(e));
    }

    final isNewFirebaseUser = credential.additionalUserInfo?.isNewUser ?? false;
    try {
      final idToken = await _requireIdToken(forceRefresh: true);
      return await _resolveGoogleUser(
        idToken: idToken,
        googleTokens: googleTokens,
        allowAutoRegister: allowAutoRegister,
        privacyConsent: privacyConsent,
        privacyNoticeVersion: privacyNoticeVersion,
      );
    } catch (_) {
      await _rollbackGoogleSession(
        deleteUser: isNewFirebaseUser ? credential.user : null,
      );
      rethrow;
    }
  }

  Future<AuthUser> _resolveGoogleUser({
    required String idToken,
    required GoogleAuthTokens googleTokens,
    required bool allowAutoRegister,
    required bool privacyConsent,
    required String privacyNoticeVersion,
  }) async {
    try {
      return await _syncSession(idToken: idToken);
    } on AuthApiException catch (error) {
      switch (classifyAuthApiFailure(error)) {
        case AuthApiFailure.notSynced:
          break;
        case AuthApiFailure.emailTaken:
          throw const AuthApiException(googleEmailTakenMessage);
        default:
          rethrow;
      }
    }

    if (!allowAutoRegister || !privacyConsent) {
      throw const AuthApiException(googleAccountNotLinkedMessage);
    }

    final email =
        _nonEmpty(googleTokens.email) ?? _nonEmpty(_auth.currentUser?.email);
    if (email == null) {
      throw const AuthApiException(
        'Tu cuenta de Google no comparte un correo. Usa correo y contraseña.',
      );
    }
    final displayName =
        _nonEmpty(googleTokens.displayName) ??
        _nonEmpty(_auth.currentUser?.displayName) ??
        email.split('@').first;

    return _registerGoogleProfile(
      idToken: idToken,
      email: email,
      displayName: displayName,
      privacyNoticeVersion: privacyNoticeVersion,
    );
  }

  Future<AuthUser> _registerGoogleProfile({
    required String idToken,
    required String email,
    required String displayName,
    required String privacyNoticeVersion,
  }) async {
    final base = _usernameFromEmail(email);
    final safeDisplayName = displayName.length > 80
        ? displayName.substring(0, 80)
        : displayName;
    AuthApiException? lastConflict;

    for (var attempt = 0; attempt <= googleUsernameRetryAttempts; attempt++) {
      final candidate = attempt == 0 ? base : _withRandomSuffix(base);
      try {
        return await _syncRegister(
          idToken: idToken,
          username: candidate,
          displayName: safeDisplayName,
          privacyConsent: true,
          privacyNoticeVersion: privacyNoticeVersion,
        );
      } on AuthApiException catch (error) {
        switch (classifyAuthApiFailure(error)) {
          case AuthApiFailure.usernameTaken:
            lastConflict = error;
            continue;
          case AuthApiFailure.emailTaken:
            throw const AuthApiException(googleEmailTakenMessage);
          default:
            rethrow;
        }
      }
    }

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

  Future<void> _rollbackGoogleSession({User? deleteUser}) async {
    if (deleteUser != null) {
      try {
        await deleteUser.delete();
      } catch (_) {}
    }
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

  /// Sufijo `_NNNN` (4 digitos). RegisterDto: 3..30 chars, `[a-zA-Z0-9_]`.
  String _withRandomSuffix(String base) {
    final suffix = '_${1000 + _random.nextInt(9000)}';
    final maxBase = 30 - suffix.length;
    final trimmed = base.length > maxBase ? base.substring(0, maxBase) : base;
    return '$trimmed$suffix';
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
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
