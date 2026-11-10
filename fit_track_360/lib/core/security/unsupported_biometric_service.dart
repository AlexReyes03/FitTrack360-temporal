import 'biometric_service.dart';

/// Implementación nula de O1: sin biometría la opción se oculta en Perfil.
/// Se sustituye por `LocalBiometricService` al integrar el paquete.
class UnsupportedBiometricService implements BiometricService {
  const UnsupportedBiometricService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}
