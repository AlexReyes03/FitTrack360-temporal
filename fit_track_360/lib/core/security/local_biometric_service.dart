import 'package:local_auth/local_auth.dart';

import 'biometric_service.dart';

/// Adaptador mínimo sobre `local_auth`, para probar [LocalBiometricService]
/// con dobles.
abstract class AuthPlugin {
  Future<bool> canCheckBiometrics();
  Future<bool> hasEnrolledBiometrics();
  Future<bool> authenticate({
    required String reason,
    required bool biometricOnly,
  });
}

/// Biometría O1 con `local_auth`. El sistema hace la verificación y la app
/// solo recibe éxito o fallo; ningún dato biométrico sale del dispositivo.
class LocalBiometricService implements BiometricService {
  LocalBiometricService({AuthPlugin? plugin})
    : _plugin = plugin ?? LocalAuthPlugin();

  final AuthPlugin _plugin;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _plugin.canCheckBiometrics() &&
          await _plugin.hasEnrolledBiometrics();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _plugin.authenticate(reason: reason, biometricOnly: true);
    } catch (_) {
      // Cancelación, bloqueo por intentos o plugin ausente: no autenticado.
      return false;
    }
  }
}

/// Implementación real del adaptador.
class LocalAuthPlugin implements AuthPlugin {
  LocalAuthPlugin([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canCheckBiometrics() => _auth.canCheckBiometrics;

  @override
  Future<bool> hasEnrolledBiometrics() async =>
      (await _auth.getAvailableBiometrics()).isNotEmpty;

  @override
  Future<bool> authenticate({
    required String reason,
    required bool biometricOnly,
  }) =>
      _auth.authenticate(localizedReason: reason, biometricOnly: biometricOnly);
}
