import 'reminder_service.dart';

/// Implementación nula de P3: la plataforma no puede programar avisos.
/// Perfil degrada la fila sin romper la vista. Se sustituye por
/// `LocalReminderService` al integrar el paquete de plataforma.
class UnsupportedReminderService implements ReminderService {
  const UnsupportedReminderService();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<ReminderPermission> requestPermission() async =>
      ReminderPermission.denied;

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> openSystemSettings() async {}
}
