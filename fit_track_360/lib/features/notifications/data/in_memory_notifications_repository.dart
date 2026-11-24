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

/// Repositorio en memoria con datos de prueba. Implementa el contrato
/// asíncrono para poder usarse como doble en pruebas sin red.
class InMemoryNotificationsRepository implements NotificationsRepository {
  InMemoryNotificationsRepository({List<AppNotification>? seed})
    : _notifications = List<AppNotification>.of(seed ?? demoNotifications());

  List<AppNotification> _notifications;

  /// Lectura síncrona usada por el ViewModel al arrancar con un seed y por
  /// pruebas heredadas que verifican el estado persistido.
  List<AppNotification> read() =>
      List<AppNotification>.unmodifiable(_notifications);

  /// Escritura síncrona de compatibilidad.
  void write(List<AppNotification> notifications) {
    _notifications = List<AppNotification>.of(notifications);
  }

  @override
  Future<List<AppNotification>> fetchNotifications({
    bool? isRead,
    AppNotificationType? type,
  }) async {
    final filtered =
        _notifications
            .where(
              (notification) =>
                  (isRead == null || notification.isRead == isRead) &&
                  (type == null || notification.type == type),
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AppNotification>.unmodifiable(filtered);
  }

  @override
  Future<int> fetchUnreadCount() async =>
      _notifications.where((notification) => !notification.isRead).length;

  @override
  Future<AppNotification?> updateRead(String id, {required bool isRead}) async {
    AppNotification? updated;
    _notifications = _notifications
        .map((notification) {
          if (notification.id != id) return notification;
          updated = notification.copyWith(
            isRead: isRead,
            readAt: isRead ? (notification.readAt ?? DateTime.now()) : null,
            clearReadAt: !isRead,
          );
          return updated!;
        })
        .toList(growable: false);
    return updated;
  }

  @override
  Future<void> markAllAsRead() async {
    final now = DateTime.now();
    _notifications = _notifications
        .map(
          (notification) => notification.isRead
              ? notification
              : notification.copyWith(
                  isRead: true,
                  readAt: notification.readAt ?? now,
                ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteNotification(String id) async {
    _notifications = _notifications
        .where((notification) => notification.id != id)
        .toList(growable: false);
  }

  @override
  Future<void> deleteAll() async {
    _notifications = const <AppNotification>[];
  }
}
