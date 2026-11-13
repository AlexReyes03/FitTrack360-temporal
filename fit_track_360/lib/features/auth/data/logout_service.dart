import '../../../core/session_storage.dart';
import 'auth_api.dart' as auth_api;

typedef RevokeRefreshToken = Future<void> Function({
  required String refreshToken,
});

/// Cierre de sesión compartido por el shell y Perfil: revoca el refresh en
/// `POST /auth/logout` y limpia [SessionStorage] siempre, aunque el API falle.
class LogoutService {
  LogoutService({SessionStorage? storage, RevokeRefreshToken? revoke})
    : _storage = storage ?? SessionStorage(),
      _revoke = revoke ?? auth_api.logout;

  final SessionStorage _storage;
  final RevokeRefreshToken _revoke;

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    try {
      if (refreshToken != null) {
        await _revoke(refreshToken: refreshToken);
      }
    } catch (_) {
      // Si el API falla, la sesión local se limpia igual.
    } finally {
      await _storage.clear();
    }
  }
}
