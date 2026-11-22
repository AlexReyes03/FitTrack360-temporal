import 'dart:async';

import '../../../core/network/api_client.dart';
import '../../../core/notifications/fcm_messaging_gateway.dart';
import '../../../core/session_storage.dart';
import 'device_token_api.dart';

/// Ciclo de vida del token FCM durante una sesión autenticada.
abstract interface class PushDeviceLifecycle {
  /// Registra el token si hay sesión, permiso y P3 activo.
  Future<void> syncForActiveSession({
    required bool notificationsEnabled,
    bool requestPermissionIfNeeded = false,
  });

  /// Cancela la escucha de rotación y revoca el token en el backend.
  Future<void> deactivateAndRevoke();

  /// Libera la instancia: cancela la suscripción y bloquea nuevos registros.
  Future<void> dispose();
}

/// Coordina permiso, token, registro y revocación de FCM.
///
/// Reglas:
/// - Sin sesión, sin soporte o con P3 apagado no registra nada.
/// - La rotación solo se reenvía mientras haya sesión y P3 activo.
/// - La revocación es best-effort con timeout corto: nunca bloquea el logout.
/// - Nunca imprime ni registra el valor del token.
class PushDeviceLifecycleService implements PushDeviceLifecycle {
  PushDeviceLifecycleService({
    required FcmMessagingGateway gateway,
    required DeviceTokenClient api,
    SessionStorage? storage,
  }) : _messagingGateway = gateway,
       _deviceApi = api,
       _storage = storage ?? appSessionStorage;

  /// Atajo para producción: gateway real y API sobre [client].
  factory PushDeviceLifecycleService.fromClient(
    ApiClient client, {
    FcmMessagingGateway? gateway,
    SessionStorage? storage,
  }) {
    return PushDeviceLifecycleService(
      gateway: gateway ?? FirebaseMessagingGateway(),
      api: DeviceTokenApi(client),
      storage: storage,
    );
  }

  final FcmMessagingGateway _messagingGateway;
  final DeviceTokenClient _deviceApi;
  final SessionStorage _storage;

  static const _revokeTimeout = Duration(seconds: 3);
  static const _tokenTimeout = Duration(seconds: 2);

  bool _notificationsEnabled = false;
  bool _disposed = false;
  String? _lastRegisteredToken;
  StreamSubscription<String>? _tokenSubscription;

  @override
  Future<void> syncForActiveSession({
    required bool notificationsEnabled,
    bool requestPermissionIfNeeded = false,
  }) async {
    if (_disposed) return;
    _notificationsEnabled = notificationsEnabled;

    if (!_messagingGateway.isSupported || !notificationsEnabled) {
      await _cancelSubscription();
      return;
    }

    try {
      if (!await _hasActiveSession()) {
        await _cancelSubscription();
        return;
      }

      final status = requestPermissionIfNeeded
          ? await _messagingGateway.requestPermission()
          : await _messagingGateway.getNotificationSettings();
      if (!_isAuthorized(status)) {
        await _cancelSubscription();
        return;
      }

      _listenTokenRefresh();

      final token = await _messagingGateway.getToken();
      if (_disposed) return;
      if (token == null || token.trim().isEmpty) return;
      if (token == _lastRegisteredToken) return;
      await _register(token.trim());
    } catch (_) {
      // Sin Play Services, APNs o red: se degrada en silencio.
    }
  }

  @override
  Future<void> deactivateAndRevoke() async {
    if (_disposed) return;
    _notificationsEnabled = false;
    await _cancelSubscription();

    final token = _lastRegisteredToken ?? await _safeGetToken();
    _lastRegisteredToken = null;
    if (_disposed) return;
    if (token == null || token.trim().isEmpty) return;

    try {
      await _deviceApi
          .revokeDeviceToken(token: token.trim())
          .timeout(_revokeTimeout);
    } catch (_) {
      // Best-effort: el logout y el apagado de P3 no se bloquean sin red.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _notificationsEnabled = false;
    _lastRegisteredToken = null;
    await _cancelSubscription();
  }

  Future<bool> _hasActiveSession() async {
    final accessToken = await _storage.readAccessToken();
    return accessToken != null && accessToken.trim().isNotEmpty;
  }

  void _listenTokenRefresh() {
    if (_disposed) return;
    if (_tokenSubscription != null) return;
    _tokenSubscription = _messagingGateway.onTokenRefresh.listen(
      (token) async {
        if (_disposed || !_notificationsEnabled) return;
        final next = token.trim();
        if (next.isEmpty || next == _lastRegisteredToken) return;
        try {
          if (!await _hasActiveSession()) return;
          if (_disposed) return;
          await _register(next);
        } catch (_) {
          // La rotación fallida se reintenta en el siguiente sync.
        }
      },
      onError: (Object _) {
        // Un error del stream no debe tumbar la app.
      },
    );
  }

  Future<void> _register(String token) async {
    if (_disposed) return;
    final platform = _messagingGateway.platformName;
    if (platform == null) return;
    await _deviceApi.registerDeviceToken(token: token, platform: platform);
    _lastRegisteredToken = token;
  }

  Future<void> _cancelSubscription() async {
    final subscription = _tokenSubscription;
    _tokenSubscription = null;
    try {
      await subscription?.cancel();
    } catch (_) {
      // La cancelación es best-effort.
    }
  }

  Future<String?> _safeGetToken() async {
    try {
      final token = (await _messagingGateway.getToken().timeout(_tokenTimeout))
          ?.trim();
      return (token == null || token.isEmpty) ? null : token;
    } catch (_) {
      return null;
    }
  }

  static bool _isAuthorized(FcmAuthorizationStatus status) =>
      status == FcmAuthorizationStatus.authorized ||
      status == FcmAuthorizationStatus.provisional;
}
