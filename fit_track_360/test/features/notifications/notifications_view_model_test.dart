import 'dart:async';

import 'package:fit_track_360/core/async_state.dart';
import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/features/notifications/data/in_memory_notifications_repository.dart';
import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
import 'package:fit_track_360/features/notifications/domain/notifications_repository.dart';
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

  group('carga remota y mutaciones (W13-6)', () {
    test('load transiciona Loading -> Data y ordena por fecha', () async {
      final repository = _FakeNotificationsRepository();
      final completer = Completer<List<AppNotification>>();
      repository.fetchCompleter = completer;
      final viewModel = NotificationsViewModel(
        repository: repository,
        initialNotifications: _seed(),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.state, isA<AsyncData<List<AppNotification>>>());
      final loading = viewModel.load();
      expect(viewModel.state, isA<AsyncLoading<List<AppNotification>>>());

      completer.complete([_seed()[2], _seed()[0]]);
      await loading;

      expect(viewModel.state, isA<AsyncData<List<AppNotification>>>());
      expect(viewModel.notifications.map((n) => n.id), ['login', 'reminder']);
      expect(viewModel.hasLoaded, isTrue);
    });

    test('load sin datos deja AsyncEmpty', () async {
      final viewModel = NotificationsViewModel(
        repository: _FakeNotificationsRepository(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.state, isA<AsyncEmpty<List<AppNotification>>>());
      expect(viewModel.isEmpty, isTrue);
      expect(viewModel.hasLoaded, isTrue);
    });

    test('load con error de red deja AsyncError', () async {
      final repository = _FakeNotificationsRepository()
        ..fetchError = Exception('sin red');
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.state, isA<AsyncError<List<AppNotification>>>());
      expect(viewModel.sessionExpired, isFalse);
    });

    test('load con sesión expirada marca sessionExpired', () async {
      final repository = _FakeNotificationsRepository()
        ..fetchError = const SessionExpiredException();
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.state, isA<AsyncError<List<AppNotification>>>());
      expect(viewModel.sessionExpired, isTrue);
    });

    test(
      'load con sesión expirada descarta los avisos de la cuenta previa',
      () async {
        final repository = _FakeNotificationsRepository(seed: _seed())
          ..fetchError = const SessionExpiredException();
        final viewModel = NotificationsViewModel(
          repository: repository,
          initialNotifications: _seed(),
        );
        addTearDown(viewModel.dispose);
        expect(viewModel.notifications, hasLength(3));

        await viewModel.load();

        expect(viewModel.notifications, isEmpty);
        expect(viewModel.unreadCount, 0);
        expect(viewModel.hasLoaded, isFalse);
        expect(viewModel.sessionExpired, isTrue);
        expect(viewModel.state, isA<AsyncError<List<AppNotification>>>());
      },
    );

    test(
      'refreshUnreadCount con sesión expirada limpia lista y badge',
      () async {
        final repository = _FakeNotificationsRepository(seed: _seed())
          ..unread = 4
          ..unreadError = const SessionExpiredException();
        final viewModel = NotificationsViewModel(repository: repository);
        addTearDown(viewModel.dispose);
        await viewModel.load();
        expect(viewModel.notifications, hasLength(3));

        await viewModel.refreshUnreadCount();

        expect(viewModel.notifications, isEmpty);
        expect(viewModel.unreadCount, 0);
        expect(viewModel.hasLoaded, isFalse);
        expect(viewModel.sessionExpired, isTrue);
      },
    );

    test('una mutación con sesión expirada no restaura el snapshot', () async {
      final repository = _FakeNotificationsRepository(seed: _seed())
        ..updateError = const SessionExpiredException();
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();
      expect(viewModel.notifications, hasLength(3));

      await viewModel.markAsRead('login');

      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);
      expect(viewModel.hasLoaded, isFalse);
      expect(viewModel.sessionExpired, isTrue);
      expect(viewModel.mutationError, isNull);
    });

    test(
      'deleteNotification con sesión expirada descarta la cuenta previa',
      () async {
        final repository = _FakeNotificationsRepository(seed: _seed())
          ..deleteError = const SessionExpiredException();
        final viewModel = NotificationsViewModel(repository: repository);
        addTearDown(viewModel.dispose);
        await viewModel.load();

        await viewModel.deleteNotification('password');

        expect(viewModel.notifications, isEmpty);
        expect(viewModel.unreadCount, 0);
        expect(viewModel.hasLoaded, isFalse);
        expect(viewModel.sessionExpired, isTrue);
      },
    );

    test(
      'tras clearOnLogout la cuenta B refresca su badge y carga sus avisos',
      () async {
        final repository = _FakeNotificationsRepository(seed: _seed())
          ..unread = 2;
        final viewModel = NotificationsViewModel(repository: repository);
        addTearDown(viewModel.dispose);
        await viewModel.load();
        expect(viewModel.unreadCount, 2);

        viewModel.clearOnLogout();
        expect(viewModel.unreadCount, 0);

        repository._items
          ..clear()
          ..add(
            AppNotification(
              id: 'b-reminder',
              title: 'Recordatorio de la cuenta B',
              message: 'Solo visible para la cuenta B.',
              type: AppNotificationType.reminder,
              createdAt: DateTime(2026, 11, 23, 8),
            ),
          );
        repository.unread = 1;

        await viewModel.refreshUnreadCount();
        expect(viewModel.unreadCount, 1);
        expect(viewModel.notifications, isEmpty);

        await viewModel.load();
        expect(viewModel.notifications.map((n) => n.id), ['b-reminder']);
        expect(viewModel.unreadCount, 1);
      },
    );

    test(
      'clearOnLogout seguido de expiración no revive la cuenta previa',
      () async {
        final repository = _FakeNotificationsRepository(seed: _seed())
          ..fetchError = const SessionExpiredException();
        final viewModel = NotificationsViewModel(
          repository: repository,
          initialNotifications: _seed(),
        );
        addTearDown(viewModel.dispose);

        viewModel.clearOnLogout();
        await viewModel.load();

        expect(viewModel.notifications, isEmpty);
        expect(viewModel.unreadCount, 0);
        expect(viewModel.hasLoaded, isFalse);
        expect(viewModel.sessionExpired, isTrue);
      },
    );

    test('refreshUnreadCount alimenta el badge antes de cargar', () async {
      final repository = _FakeNotificationsRepository()..unread = 5;
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      expect(viewModel.unreadCount, 0);
      await viewModel.refreshUnreadCount();

      expect(viewModel.unreadCount, 5);
      expect(viewModel.state, isA<AsyncLoading<List<AppNotification>>>());
    });

    test('refreshUnreadCount ignora errores de red', () async {
      final repository = _FakeNotificationsRepository()
        ..unreadError = Exception('sin red');
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      await viewModel.refreshUnreadCount();

      expect(viewModel.unreadCount, 0);
      expect(viewModel.sessionExpired, isFalse);
    });

    test('tras load, unreadCount se calcula sobre la lista', () async {
      final repository = _FakeNotificationsRepository(seed: _seed())
        ..unread = 99;
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      await viewModel.refreshUnreadCount();
      expect(viewModel.unreadCount, 99);

      await viewModel.load();
      expect(viewModel.unreadCount, 2);
    });

    test('markAsRead revierte la actualización optimista si falla', () async {
      final repository = _FakeNotificationsRepository(seed: _seed())
        ..updateError = Exception('sin red');
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      expect(viewModel.notifications.first.isRead, isFalse);
      await viewModel.markAsRead('login');

      expect(viewModel.notifications.first.isRead, isFalse);
      expect(viewModel.unreadCount, 2);
      expect(viewModel.mutationError, notificationMutationErrorMessage);

      viewModel.clearMutationError();
      expect(viewModel.mutationError, isNull);
    });

    test('toggleRead revierte si el API falla', () async {
      final repository = _FakeNotificationsRepository(seed: _seed())
        ..updateError = Exception('sin red');
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await viewModel.toggleRead('reminder');

      expect(viewModel.notifications.last.isRead, isTrue);
      expect(viewModel.unreadCount, 2);
      expect(viewModel.mutationError, notificationMutationErrorMessage);
    });

    test('deleteNotification restaura la lista si el API falla', () async {
      final repository = _FakeNotificationsRepository(seed: _seed())
        ..deleteError = Exception('sin red');
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await viewModel.deleteNotification('password');

      expect(viewModel.notifications.map((n) => n.id), [
        'login',
        'password',
        'reminder',
      ]);
      expect(viewModel.mutationError, notificationMutationErrorMessage);
    });

    test('markAllAsRead restaura la lista si el API falla', () async {
      final repository = _FakeNotificationsRepository(seed: _seed())
        ..markAllError = Exception('sin red');
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await viewModel.markAllAsRead();

      expect(viewModel.notifications.where((n) => !n.isRead), hasLength(2));
      expect(viewModel.unreadCount, 2);
      expect(viewModel.mutationError, notificationMutationErrorMessage);
    });

    test('deleteAll restaura la lista si el API falla', () async {
      final repository = _FakeNotificationsRepository(seed: _seed())
        ..deleteAllError = Exception('sin red');
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await viewModel.deleteAll();

      expect(viewModel.notifications, hasLength(3));
      expect(viewModel.state, isA<AsyncData<List<AppNotification>>>());
      expect(viewModel.mutationError, notificationMutationErrorMessage);
    });

    test('markAsRead exitoso actualiza la lista y limpia el error', () async {
      final repository = _FakeNotificationsRepository(seed: _seed());
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await viewModel.markAsRead('login');

      expect(viewModel.notifications.first.isRead, isTrue);
      expect(viewModel.unreadCount, 1);
      expect(viewModel.mutationError, isNull);
    });

    test('clearOnLogout limpia lista, badge, filtros y error', () async {
      final repository = _FakeNotificationsRepository(seed: _seed())
        ..unread = 2;
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();
      viewModel.setReadFilter(NotificationsReadFilter.unread);
      viewModel.setTypeFilter(AppNotificationType.reminder);

      viewModel.clearOnLogout();

      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);
      expect(viewModel.state, isA<AsyncEmpty<List<AppNotification>>>());
      expect(viewModel.readFilter, NotificationsReadFilter.all);
      expect(viewModel.typeFilter, isNull);
      expect(viewModel.mutationError, isNull);
      expect(viewModel.sessionExpired, isFalse);
      expect(viewModel.hasLoaded, isFalse);
    });

    test('un load en vuelo no repuebla tras clearOnLogout', () async {
      final repository = _FakeNotificationsRepository();
      final completer = Completer<List<AppNotification>>();
      repository.fetchCompleter = completer;
      final viewModel = NotificationsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      final loading = viewModel.load();
      viewModel.clearOnLogout();
      completer.complete(_seed());
      await loading;

      expect(viewModel.notifications, isEmpty);
      expect(viewModel.state, isA<AsyncEmpty<List<AppNotification>>>());
    });
  });
}

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository({List<AppNotification>? seed})
    : _items = List<AppNotification>.of(seed ?? const []);

  final List<AppNotification> _items;

  Completer<List<AppNotification>>? fetchCompleter;
  Object? fetchError;
  Object? unreadError;
  Object? updateError;
  Object? markAllError;
  Object? deleteError;
  Object? deleteAllError;
  int unread = 0;
  int fetchCalls = 0;

  @override
  Future<List<AppNotification>> fetchNotifications({
    bool? isRead,
    AppNotificationType? type,
  }) {
    fetchCalls++;
    final completer = fetchCompleter;
    if (completer != null) return completer.future;
    if (fetchError != null) return Future.error(fetchError!);
    final filtered =
        _items
            .where(
              (notification) =>
                  (isRead == null || notification.isRead == isRead) &&
                  (type == null || notification.type == type),
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Future.value(filtered);
  }

  @override
  Future<int> fetchUnreadCount() {
    if (unreadError != null) return Future.error(unreadError!);
    return Future.value(unread);
  }

  @override
  Future<AppNotification?> updateRead(String id, {required bool isRead}) {
    if (updateError != null) return Future.error(updateError!);
    AppNotification? updated;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].id != id) continue;
      updated = _items[i].copyWith(
        isRead: isRead,
        readAt: isRead ? DateTime(2026, 11, 22, 11) : null,
        clearReadAt: !isRead,
      );
      _items[i] = updated;
    }
    return Future.value(updated);
  }

  @override
  Future<void> markAllAsRead() {
    if (markAllError != null) return Future.error(markAllError!);
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].isRead) continue;
      _items[i] = _items[i].copyWith(
        isRead: true,
        readAt: DateTime(2026, 11, 22, 11),
      );
    }
    return Future<void>.value();
  }

  @override
  Future<void> deleteNotification(String id) {
    if (deleteError != null) return Future.error(deleteError!);
    _items.removeWhere((notification) => notification.id == id);
    return Future<void>.value();
  }

  @override
  Future<void> deleteAll() {
    if (deleteAllError != null) return Future.error(deleteAllError!);
    _items.clear();
    return Future<void>.value();
  }
}
