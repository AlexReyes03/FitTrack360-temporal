import 'dart:async';

import 'package:fit_track_360/core/notifications/fcm_messaging_gateway.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/notifications/data/device_token_api.dart';
import 'package:fit_track_360/features/notifications/data/push_device_lifecycle_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage implements SessionStorage {
  String? access = 'access';

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async => access;

  @override
  Future<String?> readRefreshToken() async => 'refresh';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {
    access = null;
  }
}

class FakeFcmMessagingGateway implements FcmMessagingGateway {
  bool supported = true;
  String? platform = 'android';
  FcmAuthorizationStatus settings = FcmAuthorizationStatus.authorized;
  FcmAuthorizationStatus requestResult = FcmAuthorizationStatus.authorized;
  String? token = 'tok-1';
  Object? tokenError;
  Object? settingsError;
  Object? requestError;

  int getTokenCalls = 0;
  int settingsCalls = 0;
  int requestCalls = 0;
  int deleteTokenCalls = 0;

  final _refresh = StreamController<String>.broadcast();

  @override
  bool get isSupported => supported;

  @override
  String? get platformName => platform;

  @override
  Future<FcmAuthorizationStatus> requestPermission() async {
    requestCalls++;
    if (requestError != null) throw requestError!;
    return requestResult;
  }

  @override
  Future<FcmAuthorizationStatus> getNotificationSettings() async {
    settingsCalls++;
    if (settingsError != null) throw settingsError!;
    return settings;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    if (tokenError != null) throw tokenError!;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
  }

  void emitToken(String value) => _refresh.add(value);

  Future<void> close() => _refresh.close();
}

class FakeDeviceTokenClient implements DeviceTokenClient {
  final registrations = <({String token, String platform})>[];
  final revoked = <String>[];
  Object? registerError;
  Object? revokeError;

  @override
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    if (registerError != null) throw registerError!;
    registrations.add((token: token, platform: platform));
  }

  @override
  Future<void> revokeDeviceToken({required String token}) async {
    if (revokeError != null) throw revokeError!;
    revoked.add(token);
  }
}

void main() {
  late FakeFcmMessagingGateway gateway;
  late FakeDeviceTokenClient api;
  late _FakeStorage storage;
  late PushDeviceLifecycleService service;

  setUp(() {
    gateway = FakeFcmMessagingGateway();
    api = FakeDeviceTokenClient();
    storage = _FakeStorage();
    service = PushDeviceLifecycleService(
      gateway: gateway,
      api: api,
      storage: storage,
    );
  });

  tearDown(() async {
    await service.deactivateAndRevoke();
    await gateway.close();
  });

  test('registra el token con sesión, permiso y P3 activo', () async {
    await service.syncForActiveSession(notificationsEnabled: true);

    expect(gateway.settingsCalls, 1);
    expect(gateway.requestCalls, 0);
    expect(gateway.getTokenCalls, 1);
    expect(api.registrations, [(token: 'tok-1', platform: 'android')]);
  });

  test('acepta permiso provisional', () async {
    gateway.settings = FcmAuthorizationStatus.provisional;

    await service.syncForActiveSession(notificationsEnabled: true);

    expect(api.registrations, hasLength(1));
  });

  test('no registra si P3 está apagado', () async {
    await service.syncForActiveSession(notificationsEnabled: false);

    expect(gateway.settingsCalls, 0);
    expect(gateway.getTokenCalls, 0);
    expect(api.registrations, isEmpty);
  });

  test('no registra si la plataforma no soporta FCM', () async {
    gateway.supported = false;

    await service.syncForActiveSession(notificationsEnabled: true);

    expect(gateway.settingsCalls, 0);
    expect(gateway.getTokenCalls, 0);
    expect(api.registrations, isEmpty);
  });

  test('no registra sin access token de sesión', () async {
    storage.access = null;

    await service.syncForActiveSession(notificationsEnabled: true);

    expect(gateway.settingsCalls, 0);
    expect(gateway.getTokenCalls, 0);
    expect(api.registrations, isEmpty);
  });

  test('no registra si el permiso está denegado', () async {
    gateway.settings = FcmAuthorizationStatus.denied;

    await service.syncForActiveSession(notificationsEnabled: true);

    expect(gateway.getTokenCalls, 0);
    expect(api.registrations, isEmpty);
  });

  test(
    'requestPermissionIfNeeded pide permiso en lugar de consultarlo',
    () async {
      gateway.requestResult = FcmAuthorizationStatus.authorized;

      await service.syncForActiveSession(
        notificationsEnabled: true,
        requestPermissionIfNeeded: true,
      );

      expect(gateway.requestCalls, 1);
      expect(gateway.settingsCalls, 0);
      expect(api.registrations, hasLength(1));
    },
  );

  test('re-registra cuando el token rota', () async {
    await service.syncForActiveSession(notificationsEnabled: true);

    gateway.emitToken('tok-2');
    await pumpEventQueue();

    expect(api.registrations.map((registration) => registration.token), [
      'tok-1',
      'tok-2',
    ]);
  });

  test('una sola suscripción aunque se sincronice varias veces', () async {
    await service.syncForActiveSession(notificationsEnabled: true);
    await service.syncForActiveSession(notificationsEnabled: true);

    gateway.emitToken('tok-2');
    await pumpEventQueue();

    expect(api.registrations.map((registration) => registration.token), [
      'tok-1',
      'tok-2',
    ]);
  });

  test('no re-registra en refresh si la sesión se perdió', () async {
    await service.syncForActiveSession(notificationsEnabled: true);

    storage.access = null;
    gateway.emitToken('tok-2');
    await pumpEventQueue();

    expect(api.registrations.map((registration) => registration.token), [
      'tok-1',
    ]);
  });

  test('getToken que falla no lanza ni registra', () async {
    gateway.tokenError = Exception('sin Play Services');

    await expectLater(
      service.syncForActiveSession(notificationsEnabled: true),
      completes,
    );
    expect(api.registrations, isEmpty);
  });

  test('un error del backend al registrar no lanza', () async {
    api.registerError = Exception('sin red');

    await expectLater(
      service.syncForActiveSession(notificationsEnabled: true),
      completes,
    );
    expect(api.registrations, isEmpty);
  });

  test('deactivateAndRevoke revoca y cancela la rotación', () async {
    await service.syncForActiveSession(notificationsEnabled: true);

    await service.deactivateAndRevoke();
    gateway.emitToken('tok-2');
    await pumpEventQueue();

    expect(api.revoked, ['tok-1']);
    expect(api.registrations.map((registration) => registration.token), [
      'tok-1',
    ]);
  });

  test('deactivateAndRevoke usa getToken si no hubo registro previo', () async {
    gateway.token = 'tok-fallback';

    await service.deactivateAndRevoke();

    expect(gateway.getTokenCalls, 1);
    expect(api.revoked, ['tok-fallback']);
  });

  test('deactivateAndRevoke no lanza si el API falla', () async {
    await service.syncForActiveSession(notificationsEnabled: true);
    api.revokeError = Exception('sin red');

    await expectLater(service.deactivateAndRevoke(), completes);
  });

  test('deactivateAndRevoke sin token concluye en silencio', () async {
    gateway.token = null;

    await expectLater(service.deactivateAndRevoke(), completes);
    expect(api.revoked, isEmpty);
  });
}
