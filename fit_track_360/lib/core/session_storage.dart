import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Señal global de invalidación de sesión.
///
/// Incrementa su valor cada vez que se limpia o expira la sesión (logout,
/// 401 sin refresh posible). Quien guarde estado por cuenta debe escucharla
/// para limpiarlo y evitar fugas entre cuentas.
final ValueNotifier<int> appSessionInvalidations = ValueNotifier<int>(0);

/// Marca la sesión como invalidada para que los listeners limpien su estado.
void notifySessionCleared() => appSessionInvalidations.value++;

/// Contrato de sesión: Bearer = ID token (Firebase en prod; fake/secure en tests).
abstract class SessionStorage {
  Future<String?> readAccessToken({bool forceRefresh = false});

  /// Obsoleto con Firebase Auth (1A). Las fakes pueden ignorarlo.
  Future<String?> readRefreshToken();

  /// Con Firebase la sesión vive en el SDK; este método es no-op o cache local.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clear();
}

/// Instancia usada por router y pantallas de producción.
/// En tests se sustituye inyectando fakes en widgets / ApiClient.
SessionStorage appSessionStorage = SecureSessionStorage();

/// Almacenamiento local (tests o migración). No es la fuente de verdad con Firebase.
class SecureSessionStorage implements SessionStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) =>
      _storage.read(key: _accessTokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    notifySessionCleared();
  }
}

/// Sesión respaldada por Firebase Auth (AUTH-01 / decisión 1A).
class FirebaseSessionStorage implements SessionStorage {
  FirebaseSessionStorage({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // La sesión la mantiene Firebase Auth; no se duplica en secure storage.
  }

  @override
  Future<void> clear() async {
    await _auth.signOut();
    notifySessionCleared();
  }
}
