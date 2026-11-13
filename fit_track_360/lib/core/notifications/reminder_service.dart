/// Resultado de pedir permiso para mostrar el recordatorio (P3).
enum ReminderPermission { granted, denied, permanentlyDenied }

/// Recordatorio local diario para entrenar o registrar comidas (P3).
///
/// La vista de Perfil depende solo de esta interfaz; la implementación con
/// `flutter_local_notifications` vive en `local_reminder_service.dart`.
abstract class ReminderService {
  /// `false` si la plataforma no puede programar notificaciones locales.
  Future<bool> isSupported();

  /// Pide `POST_NOTIFICATIONS` (Android 13+) o la autorización de iOS.
  Future<ReminderPermission> requestPermission();

  /// Programa el aviso diario a [hour]:[minute] (hora local, inexacta).
  Future<void> scheduleDaily({required int hour, required int minute});

  /// Cancela el recordatorio programado, si existe.
  Future<void> cancel();

  /// Abre los ajustes del sistema cuando el permiso quedó denegado.
  Future<void> openSystemSettings();
}
