import 'app_notification.dart';

/// Persistencia del centro de notificaciones.
///
/// La implementación en memoria permite pruebas sin red; en producción la
/// sustituye `NotificationsApiRepository` sobre `ApiClient`.
abstract interface class NotificationsRepository {
  Future<List<AppNotification>> fetchNotifications({
    bool? isRead,
    AppNotificationType? type,
  });

  Future<int> fetchUnreadCount();

  Future<AppNotification?> updateRead(String id, {required bool isRead});

  Future<void> markAllAsRead();

  Future<void> deleteNotification(String id);

  Future<void> deleteAll();
}
