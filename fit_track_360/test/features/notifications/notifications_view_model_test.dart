import 'package:fit_track_360/features/notifications/data/in_memory_notifications_repository.dart';
import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

List<AppNotification> _seed() {
  return [
    AppNotification(
      id: 'login',
      title: 'Nuevo inicio de sesión',
      message: 'Se inició sesión en un dispositivo Android.',
      type: AppNotificationType.newLogin,
      createdAt: DateTime(2026, 11, 22, 10),
    ),
    AppNotification(
      id: 'password',
      title: 'Contraseña actualizada',
      message: 'Tu contraseña se cambió correctamente.',
      type: AppNotificationType.passwordChanged,
      createdAt: DateTime(2026, 11, 22, 9),
    ),
    AppNotification(
      id: 'reminder',
      title: 'Recordatorio de entrenamiento',
      message: 'Registra tu sesión de hoy.',
      type: AppNotificationType.reminder,
      createdAt: DateTime(2026, 11, 21, 20),
      isRead: true,
    ),
  ];
}

void main() {
  test('los datos de prueba cubren los 3 tipos y mezclan leídas', () {
    final viewModel = NotificationsViewModel();
    addTearDown(viewModel.dispose);

    expect(
      viewModel.notifications.map((n) => n.type).toSet(),
      containsAll(AppNotificationType.values),
    );
    expect(viewModel.notifications.any((n) => n.isRead), isTrue);
    expect(viewModel.notifications.any((n) => !n.isRead), isTrue);
    expect(viewModel.unreadCount, 3);
    expect(viewModel.hasUnread, isTrue);
  });

  test('ordena de la más reciente a la más antigua', () {
    final viewModel = NotificationsViewModel(
      repository: InMemoryNotificationsRepository(seed: _seed()),
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.notifications.map((n) => n.id), [
      'login',
      'password',
      'reminder',
    ]);
  });

  test('filtra por estado de lectura', () {
    final viewModel = NotificationsViewModel(
      repository: InMemoryNotificationsRepository(seed: _seed()),
    );
    addTearDown(viewModel.dispose);

    viewModel.setReadFilter(NotificationsReadFilter.unread);
    expect(viewModel.filteredNotifications.map((n) => n.id), [
      'login',
      'password',
    ]);

    viewModel.setReadFilter(NotificationsReadFilter.read);
    expect(viewModel.filteredNotifications.map((n) => n.id), ['reminder']);

    viewModel.setReadFilter(NotificationsReadFilter.all);
    expect(viewModel.filteredNotifications, hasLength(3));
  });

  test('filtra por tipo y lo combina con el estado de lectura', () {
    final viewModel = NotificationsViewModel(
      repository: InMemoryNotificationsRepository(seed: _seed()),
    );
    addTearDown(viewModel.dispose);

    viewModel.setTypeFilter(AppNotificationType.reminder);
    expect(viewModel.filteredNotifications.map((n) => n.id), ['reminder']);

    viewModel.setReadFilter(NotificationsReadFilter.unread);
    expect(viewModel.filteredNotifications, isEmpty);

    viewModel.setReadFilter(NotificationsReadFilter.read);
    expect(viewModel.filteredNotifications.map((n) => n.id), ['reminder']);
  });

  test('clearFilters restaura la lista completa', () {
    final viewModel = NotificationsViewModel(
      repository: InMemoryNotificationsRepository(seed: _seed()),
    );
    addTearDown(viewModel.dispose);

    viewModel.setReadFilter(NotificationsReadFilter.unread);
    viewModel.setTypeFilter(AppNotificationType.newLogin);
    viewModel.clearFilters();

    expect(viewModel.readFilter, NotificationsReadFilter.all);
    expect(viewModel.typeFilter, isNull);
    expect(viewModel.filteredNotifications, hasLength(3));
  });

  test('markAsRead actualiza isRead, el badge y notifica', () {
    final repository = InMemoryNotificationsRepository(seed: _seed());
    final viewModel = NotificationsViewModel(repository: repository);
    addTearDown(viewModel.dispose);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.markAsRead('login');

    expect(viewModel.notifications.first.isRead, isTrue);
    expect(viewModel.unreadCount, 1);
    expect(viewModel.hasUnread, isTrue);
    expect(notifications, 1);
    expect(repository.read().first.isRead, isTrue);
  });

  test('markAsRead es idempotente y no notifica si no cambia', () {
    final viewModel = NotificationsViewModel(
      repository: InMemoryNotificationsRepository(seed: _seed()),
    );
    addTearDown(viewModel.dispose);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.markAsRead('login');
    viewModel.markAsRead('login');

    expect(notifications, 1);
  });

  test('toggleRead alterna leída y no leída', () {
    final viewModel = NotificationsViewModel(
      repository: InMemoryNotificationsRepository(seed: _seed()),
    );
    addTearDown(viewModel.dispose);

    viewModel.toggleRead('reminder');
    expect(viewModel.notifications.last.isRead, isFalse);
    expect(viewModel.unreadCount, 3);

    viewModel.toggleRead('reminder');
    expect(viewModel.notifications.last.isRead, isTrue);
    expect(viewModel.unreadCount, 2);
  });

  test('markAllAsRead deja el badge en cero', () {
    final viewModel = NotificationsViewModel(
      repository: InMemoryNotificationsRepository(seed: _seed()),
    );
    addTearDown(viewModel.dispose);

    viewModel.markAllAsRead();

    expect(viewModel.unreadCount, 0);
    expect(viewModel.hasUnread, isFalse);
    expect(viewModel.notifications.every((n) => n.isRead), isTrue);
  });

  test('deleteNotification elimina solo el aviso indicado', () {
    final repository = InMemoryNotificationsRepository(seed: _seed());
    final viewModel = NotificationsViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    viewModel.deleteNotification('password');

    expect(viewModel.notifications.map((n) => n.id), ['login', 'reminder']);
    expect(viewModel.unreadCount, 1);
    expect(repository.read().map((n) => n.id), ['login', 'reminder']);
  });

  test('deleteAll deja la lista vacía y el badge en cero', () {
    final repository = InMemoryNotificationsRepository(seed: _seed());
    final viewModel = NotificationsViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    viewModel.deleteAll();

    expect(viewModel.notifications, isEmpty);
    expect(viewModel.filteredNotifications, isEmpty);
    expect(viewModel.unreadCount, 0);
    expect(viewModel.hasUnread, isFalse);
    expect(viewModel.isEmpty, isTrue);
    expect(repository.read(), isEmpty);
  });

  test('el repositorio conserva el estado entre ViewModels', () {
    final repository = InMemoryNotificationsRepository(seed: _seed());
    final first = NotificationsViewModel(repository: repository);
    first.markAsRead('login');
    first.deleteNotification('reminder');
    first.dispose();

    final second = NotificationsViewModel(repository: repository);
    addTearDown(second.dispose);

    expect(second.notifications.map((n) => n.id), ['login', 'password']);
    expect(second.notifications.first.isRead, isTrue);
    expect(second.unreadCount, 1);
  });
}
