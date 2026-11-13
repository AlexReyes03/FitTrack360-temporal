import 'user_profile.dart';

/// La exportación (`GET /api/v1/users/me/export`) no existe o falló.
class ExportUnavailableException implements Exception {
  const ExportUnavailableException();

  @override
  String toString() => 'Exportación no disponible';
}

/// Acceso al perfil del usuario autenticado.
abstract class ProfileRepository {
  /// Devuelve null si el API no tiene perfil que mostrar.
  Future<UserProfile?> fetchProfile();

  Future<UserProfile> updateProfile(ProfileUpdate update);

  /// Número de sesiones de entrenamiento registradas (resumen histórico).
  Future<int> countWorkouts();

  /// JSON con los datos del usuario. Lanza [ExportUnavailableException].
  Future<String> exportData();
}
