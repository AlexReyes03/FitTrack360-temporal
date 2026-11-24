import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../data/in_memory_notifications_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notifications_repository.dart';

/// Mensaje neutro para fallos de mutación (se conserva la lista anterior).
const notificationMutationErrorMessage =
    'No se pudo actualizar la notificación. Intenta de nuevo.';

/// Confirmación tras marcar todas las notificaciones como leídas.
const notificationsMarkedAllReadMessage =
    'Listo: marcaste todas las notificaciones como leídas.';

/// Filtro por estado de lectura del centro de avisos.
enum NotificationsReadFilter { all, unread, read }

/// Estado y acciones del centro de notificaciones.
///
/// La lista se mantiene ordenada de la más reciente a la más antigua. Cada
/// mutación es optimista: primero se actualiza la lista local y, si el API
/// falla, se restaura la instantánea previa y se expone [mutationError].
class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({
    NotificationsRepository? repository,
    List<AppNotification>? initialNotifications,
    bool autoLoad = false,
  }) : _repository =
           repository ??
           InMemoryNotificationsRepository(seed: initialNotifications) {
    final seed =
        initialNotifications ??
        (_repository is InMemoryNotificationsRepository
            ? _repository.read()
            : null);
    if (seed != null) {
      _notifications = _sorted(seed);
      _remoteUnreadCount = _countUnread(_notifications);
      _hasLoaded = true;
      state = _stateFor(_notifications);
    }
    if (autoLoad) unawaited(load());
  }

  final NotificationsRepository _repository;

  List<AppNotification> _notifications = const <AppNotification>[];
  NotificationsReadFilter _readFilter = NotificationsReadFilter.all;
  AppNotificationType? _typeFilter;
  int? _remoteUnreadCount;
  bool _hasLoaded = false;
  bool _loading = false;
  bool _disposed = false;
  int _sessionEpoch = 0;

  /// Estado remoto de la lista (cargando, datos, error o vacío).
  AsyncState<List<AppNotification>> state =
      const AsyncLoading<List<AppNotification>>();

  /// Error no bloqueante de la última mutación; la UI lo muestra y lo limpia.
  String? mutationError;

  /// Confirmación no bloqueante de la última acción masiva exitosa; la UI la
  /// muestra y la limpia con [clearConfirmationMessage].
  String? confirmationMessage;

  /// true si el API reportó que la sesión ya no se puede renovar.
  bool sessionExpired = false;

  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);

  NotificationsReadFilter get readFilter => _readFilter;
  AppNotificationType? get typeFilter => _typeFilter;

  /// true cuando ya se intentó cargar en esta sesión (éxito o error).
  bool get hasLoaded => _hasLoaded;

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

  /// Antes de cargar la lista se usa el conteo remoto del badge; después se
  /// calcula sobre la lista ya filtrada por el backend.
  int get unreadCount {
    if (_hasLoaded &&
        (state is AsyncData<List<AppNotification>> ||
            state is AsyncEmpty<List<AppNotification>>)) {
      return _countUnread(_notifications);
    }
    return _remoteUnreadCount ?? 0;
  }

  bool get hasUnread => unreadCount > 0;

  bool get isEmpty => _notifications.isEmpty;

  void setReadFilter(NotificationsReadFilter filter) {
    if (_readFilter == filter) return;
    _readFilter = filter;
    _notify();
  }

  void setTypeFilter(AppNotificationType? type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    _notify();
  }

  void clearFilters() {
    if (_readFilter == NotificationsReadFilter.all && _typeFilter == null) {
      return;
    }
    _readFilter = NotificationsReadFilter.all;
    _typeFilter = null;
    _notify();
  }

  /// Carga la lista remota y transiciona por [AsyncLoading].
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    final epoch = _sessionEpoch;
    state = const AsyncLoading<List<AppNotification>>();
    mutationError = null;
    _notify();

    try {
      final fetched = await _repository.fetchNotifications();
      if (_disposed || epoch != _sessionEpoch) return;
      _notifications = _sorted(fetched);
      _remoteUnreadCount = _countUnread(_notifications);
      _hasLoaded = true;
      sessionExpired = false;
      state = _stateFor(_notifications);
    } on SessionExpiredException {
      if (_disposed || epoch != _sessionEpoch) return;
      _expireSession();
      state = const AsyncError<List<AppNotification>>(
        SessionExpiredException(),
      );
    } catch (error, stackTrace) {
      if (_disposed || epoch != _sessionEpoch) return;
      _hasLoaded = true;
      state = AsyncError<List<AppNotification>>(error, stackTrace);
    } finally {
      if (epoch == _sessionEpoch) _loading = false;
      _notify();
    }
  }

  /// Actualiza el conteo del badge sin tocar la lista ni mostrar errores.
  Future<void> refreshUnreadCount() async {
    final epoch = _sessionEpoch;
    try {
      final count = await _repository.fetchUnreadCount();
      if (_disposed || epoch != _sessionEpoch) return;
      final changed = _remoteUnreadCount != count;
      _remoteUnreadCount = count;
      sessionExpired = false;
      if (changed) _notify();
    } on SessionExpiredException {
      if (_disposed || epoch != _sessionEpoch) return;
      _expireSession();
      _notify();
    } catch (_) {
      // Silencioso: el badge no debe romper la navegación sin red.
    }
  }

  Future<void> markAsRead(String id) => _updateRead(id, isRead: true);

  /// Abre una notificación: la marca como leída (nunca la regresa a no leída)
  /// y devuelve su ruta interna, o null si no tiene destino.
  Future<String?> openNotification(String id) async {
    final current = _notificationById(id);
    if (current == null) return null;
    final route = current.targetRoute;
    if (!current.isRead) await _updateRead(id, isRead: true);
    return route;
  }

  Future<void> toggleRead(String id) async {
    final current = _notificationById(id);
    if (current == null) return;
    await _updateRead(id, isRead: !current.isRead);
  }

  Future<void> markAllAsRead() async {
    if (!hasUnread) return;

    final epoch = _sessionEpoch;
    final snapshot = _notifications;
    final remoteSnapshot = _remoteUnreadCount;
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
    _syncLoadedState();
    mutationError = null;
    confirmationMessage = null;
    _notify();

    try {
      await _repository.markAllAsRead();
      if (_disposed || epoch != _sessionEpoch) return;
      _remoteUnreadCount = 0;
      confirmationMessage = notificationsMarkedAllReadMessage;
      _notify();
    } on SessionExpiredException {
      if (_disposed || epoch != _sessionEpoch) return;
      _failMutation(snapshot, remoteSnapshot, expired: true);
    } catch (_) {
      if (_disposed || epoch != _sessionEpoch) return;
      _failMutation(snapshot, remoteSnapshot);
    }
  }

  Future<void> deleteNotification(String id) async {
    final epoch = _sessionEpoch;
    final snapshot = _notifications;
    final next = _notifications
        .where((notification) => notification.id != id)
        .toList(growable: false);
    if (next.length == snapshot.length) return;

    final remoteSnapshot = _remoteUnreadCount;
    _notifications = next;
    _syncLoadedState();
    mutationError = null;
    _notify();

    try {
      await _repository.deleteNotification(id);
      if (_disposed || epoch != _sessionEpoch) return;
      _remoteUnreadCount = _countUnread(_notifications);
    } on SessionExpiredException {
      if (_disposed || epoch != _sessionEpoch) return;
      _failMutation(snapshot, remoteSnapshot, expired: true);
    } catch (_) {
      if (_disposed || epoch != _sessionEpoch) return;
      _failMutation(snapshot, remoteSnapshot);
    }
  }

  Future<void> deleteAll() async {
    if (_notifications.isEmpty) return;

    final epoch = _sessionEpoch;
    final snapshot = _notifications;
    final remoteSnapshot = _remoteUnreadCount;
    _notifications = const <AppNotification>[];
    _syncLoadedState();
    mutationError = null;
    _notify();

    try {
      await _repository.deleteAll();
      if (_disposed || epoch != _sessionEpoch) return;
      _remoteUnreadCount = 0;
    } on SessionExpiredException {
      if (_disposed || epoch != _sessionEpoch) return;
      _failMutation(snapshot, remoteSnapshot, expired: true);
    } catch (_) {
      if (_disposed || epoch != _sessionEpoch) return;
      _failMutation(snapshot, remoteSnapshot);
    }
  }

  void clearMutationError() {
    if (mutationError == null) return;
    mutationError = null;
    _notify();
  }

  void clearConfirmationMessage() {
    if (confirmationMessage == null) return;
    confirmationMessage = null;
    _notify();
  }

  /// Limpia el estado al cerrar sesión para no filtrar datos entre cuentas.
  void clearOnLogout() {
    _sessionEpoch++;
    _loading = false;
    _hasLoaded = false;
    _notifications = const <AppNotification>[];
    _remoteUnreadCount = 0;
    mutationError = null;
    confirmationMessage = null;
    sessionExpired = false;
    _readFilter = NotificationsReadFilter.all;
    _typeFilter = null;
    state = const AsyncEmpty<List<AppNotification>>();
    _notify();
  }

  AppNotification? _notificationById(String id) {
    for (final notification in _notifications) {
      if (notification.id == id) return notification;
    }
    return null;
  }

  Future<void> _updateRead(String id, {required bool isRead}) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index < 0) return;

    final current = _notifications[index];
    if (current.isRead == isRead) return;

    final epoch = _sessionEpoch;
    final snapshot = _notifications;
    final remoteSnapshot = _remoteUnreadCount;
    final updated = current.copyWith(
      isRead: isRead,
      readAt: isRead ? (current.readAt ?? DateTime.now()) : null,
      clearReadAt: !isRead,
    );
    _notifications = List<AppNotification>.of(_notifications)
      ..[index] = updated;
    _syncLoadedState();
    mutationError = null;
    _notify();

    try {
      await _repository.updateRead(id, isRead: isRead);
      if (_disposed || epoch != _sessionEpoch) return;
      _remoteUnreadCount = _countUnread(_notifications);
    } on SessionExpiredException {
      if (_disposed || epoch != _sessionEpoch) return;
      _failMutation(snapshot, remoteSnapshot, expired: true);
    } catch (_) {
      if (_disposed || epoch != _sessionEpoch) return;
      _failMutation(snapshot, remoteSnapshot);
    }
  }

  void _failMutation(
    List<AppNotification> snapshot,
    int? remoteSnapshot, {
    bool expired = false,
  }) {
    if (expired) {
      _expireSession();
      _notify();
      return;
    }
    _notifications = snapshot;
    _remoteUnreadCount = remoteSnapshot;
    mutationError = notificationMutationErrorMessage;
    _syncLoadedState();
    _notify();
  }

  /// La sesión ya no se puede renovar: se descarta todo lo de la cuenta
  /// anterior para que la siguiente sesión no herede avisos ni conteos.
  void _expireSession() {
    _sessionEpoch++;
    _loading = false;
    _notifications = const <AppNotification>[];
    _remoteUnreadCount = 0;
    _hasLoaded = false;
    mutationError = null;
    sessionExpired = true;
    state = const AsyncEmpty<List<AppNotification>>();
  }

  void _syncLoadedState() {
    if (state is AsyncData<List<AppNotification>> ||
        state is AsyncEmpty<List<AppNotification>>) {
      state = _stateFor(_notifications);
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static AsyncState<List<AppNotification>> _stateFor(
    List<AppNotification> notifications,
  ) => notifications.isEmpty
      ? const AsyncEmpty<List<AppNotification>>()
      : AsyncData<List<AppNotification>>(notifications);

  static int _countUnread(List<AppNotification> notifications) =>
      notifications.where((notification) => !notification.isRead).length;

  static List<AppNotification> _sorted(List<AppNotification> notifications) {
    final sorted = List<AppNotification>.of(notifications);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AppNotification>.unmodifiable(sorted);
  }
}
