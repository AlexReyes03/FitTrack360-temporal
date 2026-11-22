import '../domain/app_notification.dart';
import '../domain/notifications_repository.dart';

/// Datos de prueba realistas para la primera versión del centro de avisos.
///
/// Mezcla avisos leídos y no leídos de los tres tipos planificados. La fecha
/// base es inyectable para que las pruebas no dependan del reloj real.
List<AppNotification> demoNotifications({DateTime? now}) {
  final base = now ?? DateTime.now();
  return [
    AppNotification(
      id: 'demo-login-1',
      title: 'Nuevo inicio de sesión',
      message:
          'Se inició sesión en un dispositivo Android. Si no fuiste tú, '
          'cambia tu contraseña.',
      type: AppNotificationType.newLogin,
      createdAt: base.subtract(const Duration(minutes: 12)),
    ),
    AppNotification(
      id: 'demo-password-1',
      title: 'Contraseña actualizada',
      message: 'Tu contraseña se cambió correctamente hace unos minutos.',
      type: AppNotificationType.passwordChanged,
      createdAt: base.subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: 'demo-reminder-1',
      title: 'Recordatorio de entrenamiento',
      message: 'No olvides registrar tu sesión de hoy para mantener la racha.',
      type: AppNotificationType.reminder,
      createdAt: base.subtract(const Duration(hours: 8)),
      isRead: true,
    ),
    AppNotification(
      id: 'demo-login-2',
      title: 'Nuevo inicio de sesión',
      message: 'Se inició sesión en un dispositivo iOS desde otra ciudad.',
      type: AppNotificationType.newLogin,
      createdAt: base.subtract(const Duration(days: 1, hours: 2)),
      isRead: true,
    ),
    AppNotification(
      id: 'demo-reminder-2',
      title: 'Recordatorio de comidas',
      message: 'Registra tus comidas del día para ver tu resumen de macros.',
      type: AppNotificationType.reminder,
      createdAt: base.subtract(const Duration(days: 2)),
    ),
  ];
}

/// Repositorio en memoria con datos de prueba. Sirve como contrato para una
/// futura implementación remota.
class InMemoryNotificationsRepository implements NotificationsRepository {
  InMemoryNotificationsRepository({List<AppNotification>? seed})
    : _notifications = List<AppNotification>.of(seed ?? demoNotifications());

  List<AppNotification> _notifications;

  @override
  List<AppNotification> read() =>
      List<AppNotification>.unmodifiable(_notifications);

  @override
  void write(List<AppNotification> notifications) {
    _notifications = List<AppNotification>.of(notifications);
  }
}
