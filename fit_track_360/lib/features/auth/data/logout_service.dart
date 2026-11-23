import '../../../core/session_storage.dart';
import 'auth_api.dart' as auth_api;
import 'firebase_auth_service.dart';

typedef RevokeIdToken = Future<void> Function({required String idToken});

/// Cierre de sesión: revoca en Nest (si hay red) y limpia Firebase / storage.
class LogoutService {
  LogoutService({SessionStorage? storage, this.revoke, this.firebaseAuth})
    : _storage = storage ?? appSessionStorage;

  final SessionStorage _storage;
  final RevokeIdToken? revoke;
  final FirebaseAuthService? firebaseAuth;

  /// [revokeRemote] false cuando la cuenta ya se eliminó: no queda sesión que
  /// revocar y la limpieza local no debe esperar a la red.
  Future<void> logout({bool revokeRemote = true}) async {
    if (firebaseAuth != null) {
      await firebaseAuth!.logout();
      return;
    }

    String? idToken;
    try {
      idToken = await _storage.readAccessToken();
    } catch (_) {
      // La limpieza local se ejecuta aunque no se pueda leer el token.
    }
    try {
      if (revokeRemote && idToken != null && revoke != null) {
        await revoke!(idToken: idToken);
      } else if (revokeRemote && idToken != null) {
        await auth_api.revokeRemoteSession(idToken: idToken);
      }
    } catch (_) {
      // Si el API falla, la sesión local se limpia igual.
    } finally {
      await _storage.clear();
    }
  }
}
