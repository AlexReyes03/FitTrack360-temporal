import 'package:flutter/foundation.dart';

import '../data/in_memory_notifications_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notifications_repository.dart';

/// Filtro por estado de lectura del centro de avisos.
enum NotificationsReadFilter { all, unread, read }

/// Estado y acciones del centro de notificaciones.
///
/// La lista se mantiene ordenada de la más reciente a la más antigua. Cada
/// mutación se escribe en el repositorio y notifica a los listeners para que
/// el badge de la campana y la lista reaccionen juntos.
class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({
    NotificationsRepository? repository,
    List<AppNotification>? initialNotifications,
  }) : _repository =
           repository ??
           InMemoryNotificationsRepository(seed: initialNotifications) {
    _notifications = _sorted(_repository.read());
  }

  final NotificationsRepository _repository;
  late List<AppNotification> _notifications;
  NotificationsReadFilter _readFilter = NotificationsReadFilter.all;
  AppNotificationType? _typeFilter;

  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);

  NotificationsReadFilter get readFilter => _readFilter;
  AppNotificationType? get typeFilter => _typeFilter;

  /// Avisos visibles con los filtros activos.
  List<AppNotification> get filteredNotifications {
    return _notifications
        .where((notification) {
          final matchesRead = switch (_readFilter) {
            NotificationsReadFilter.all => true,
            NotificationsReadFilter.unread => !notification.isRead,
            NotificationsReadFilter.read => notification.isRead,
          };
          final matchesType =
              _typeFilter == null || notification.type == _typeFilter;
          return matchesRead && matchesType;
        })
        .toList(growable: false);
  }

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  bool get hasUnread => unreadCount > 0;

  bool get isEmpty => _notifications.isEmpty;

  void setReadFilter(NotificationsReadFilter filter) {
    if (_readFilter == filter) return;
    _readFilter = filter;
    notifyListeners();
  }

  void setTypeFilter(AppNotificationType? type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    if (_readFilter == NotificationsReadFilter.all && _typeFilter == null) {
      return;
    }
    _readFilter = NotificationsReadFilter.all;
    _typeFilter = null;
    notifyListeners();
  }

  void markAsRead(String id) => _updateRead(id, isRead: true);

  void toggleRead(String id) {
    final current = _notificationById(id);
    if (current == null) return;
    _updateRead(id, isRead: !current.isRead);
  }

  void markAllAsRead() {
    if (!hasUnread) return;
    _notifications = _notifications
        .map(
          (notification) => notification.isRead
              ? notification
              : notification.copyWith(isRead: true),
        )
        .toList(growable: false);
    _persistAndNotify();
  }

  void deleteNotification(String id) {
    final next = _notifications
        .where((notification) => notification.id != id)
        .toList(growable: false);
    if (next.length == _notifications.length) return;
    _notifications = next;
    _persistAndNotify();
  }

  void deleteAll() {
    if (_notifications.isEmpty) return;
    _notifications = const <AppNotification>[];
    _persistAndNotify();
  }

  AppNotification? _notificationById(String id) {
    for (final notification in _notifications) {
      if (notification.id == id) return notification;
    }
    return null;
  }

  void _updateRead(String id, {required bool isRead}) {
    var changed = false;
    final next = _notifications
        .map((notification) {
          if (notification.id != id || notification.isRead == isRead) {
            return notification;
          }
          changed = true;
          return notification.copyWith(isRead: isRead);
        })
        .toList(growable: false);
    if (!changed) return;
    _notifications = next;
    _persistAndNotify();
  }

  void _persistAndNotify() {
    _repository.write(_notifications);
    notifyListeners();
  }

  static List<AppNotification> _sorted(List<AppNotification> notifications) {
    final sorted = List<AppNotification>.of(notifications);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AppNotification>.unmodifiable(sorted);
  }
}
