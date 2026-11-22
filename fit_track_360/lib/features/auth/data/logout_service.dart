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

  Future<void> logout() async {
    if (firebaseAuth != null) {
      await firebaseAuth!.logout();
      notifySessionCleared();
      return;
    }

    final idToken = await _storage.readAccessToken();
    try {
      if (idToken != null && revoke != null) {
        await revoke!(idToken: idToken);
      } else if (idToken != null) {
        await auth_api.revokeRemoteSession(idToken: idToken);
      }
    } catch (_) {
      // Si el API falla, la sesión local se limpia igual.
    } finally {
      await _storage.clear();
      notifySessionCleared();
    }
  }
}
