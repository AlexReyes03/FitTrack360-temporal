/// Desbloqueo o confirmación con huella o rostro (O1).
///
/// Ningún dato biométrico sale del dispositivo: la app solo recibe éxito o
/// fallo del sistema. La implementación con `local_auth` vive en
/// `local_biometric_service.dart`.
abstract class BiometricService {
  /// `false` si el dispositivo no tiene biometría configurada; la opción se
  /// oculta en Perfil.
  Future<bool> isAvailable();

  /// Muestra el diálogo del sistema con [reason] y devuelve si se autenticó.
  Future<bool> authenticate({required String reason});
}
