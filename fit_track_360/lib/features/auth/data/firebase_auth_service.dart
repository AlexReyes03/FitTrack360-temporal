import 'package:firebase_auth/firebase_auth.dart';

import 'auth_api.dart';

/// Auth remoto: Firebase Auth + sync Nest (AUTH-01).
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

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
      await _auth.signOut();
    }
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
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta mas tarde';
      case 'network-request-failed':
        return 'No se pudo conectar';
      default:
        return e.message ?? 'No se pudo completar la autenticacion';
    }
  }
}
