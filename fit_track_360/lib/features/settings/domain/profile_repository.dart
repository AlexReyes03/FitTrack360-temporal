import 'user_profile.dart';

/// La exportación (`GET /api/v1/users/me/export`) no existe o falló.
class ExportUnavailableException implements Exception {
  const ExportUnavailableException();

  @override
  String toString() => 'Exportación no disponible';
}

/// Acceso al perfil del usuario autenticado.
abstract class ProfileRepository {
  /// Devuelve null si el API no tiene perfil que mostrar. El resumen
  /// histórico llega en [UserProfile.workoutCount], sin listar sesiones.
  Future<UserProfile?> fetchProfile();

  Future<UserProfile> updateProfile(ProfileUpdate update);

  /// JSON con los datos del usuario. Lanza [ExportUnavailableException].
  Future<String> exportData();

  /// Elimina la cuenta del usuario autenticado.
  Future<void> deleteAccount();
}
