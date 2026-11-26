import '../../../core/session_storage.dart';
import '../../notifications/data/push_device_lifecycle_service.dart';
import 'auth_api.dart' as auth_api;
import 'firebase_auth_service.dart';

typedef RevokeIdToken = Future<void> Function({required String idToken});

/// Cierre de sesión: revoca el token FCM, revoca en Nest (si hay red) y limpia
/// Firebase / storage.
class LogoutService {
  LogoutService({
    SessionStorage? storage,
    this.revoke,
    this.firebaseAuth,
    this.pushDeviceService,
  }) : _storage = storage ?? appSessionStorage;

  final SessionStorage _storage;
  final RevokeIdToken? revoke;
  final FirebaseAuthService? firebaseAuth;
  final PushDeviceLifecycle? pushDeviceService;

  /// [revokeRemote] false cuando la cuenta ya se eliminó: no queda sesión ni
  /// token FCM que revocar (el DeviceToken se borra en cascada) y la limpieza
  /// local no debe esperar a la red.
  Future<void> logout({bool revokeRemote = true}) async {
    final push = pushDeviceService;
    if (revokeRemote && push != null) {
      // La revocación viaja autenticada con el Bearer vigente y nunca bloquea.
      try {
        await push.deactivateAndRevoke().timeout(const Duration(seconds: 4));
      } catch (_) {
        // Sin red o sin token: el cierre de sesión continúa.
      }
    }

    if (firebaseAuth != null) {
      await firebaseAuth!.logout();
      notifySessionCleared();
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
      notifySessionCleared();
    }
  }
}
