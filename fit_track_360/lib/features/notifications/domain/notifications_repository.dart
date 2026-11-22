import 'app_notification.dart';

/// Persistencia mínima del centro de notificaciones. La implementación en
/// memoria permite sustituirla por una API sin cambiar el ViewModel.
abstract interface class NotificationsRepository {
  List<AppNotification> read();

  void write(List<AppNotification> notifications);
}
