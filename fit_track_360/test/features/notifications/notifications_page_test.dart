import 'dart:async';

import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
import 'package:fit_track_360/features/notifications/domain/notifications_repository.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_page.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<AppNotification> _seed() {
  final now = DateTime.now();
  return [
    AppNotification(
      id: 'n-login',
      title: 'Nuevo inicio de sesión',
      message: 'Se inició sesión en Android.',
      type: AppNotificationType.newLogin,
      createdAt: now.subtract(const Duration(minutes: 10)),
    ),
    AppNotification(
      id: 'n-password',
      title: 'Contraseña actualizada',
      message: 'Tu contraseña se cambió correctamente.',
      type: AppNotificationType.passwordChanged,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n-reminder',
      title: 'Recordatorio de entrenamiento',
      message: 'Registra tu sesión de hoy.',
      type: AppNotificationType.reminder,
      createdAt: now.subtract(const Duration(hours: 6)),
      isRead: true,
    ),
  ];
}

Future<NotificationsViewModel> _pumpPage(
  WidgetTester tester, {
  List<AppNotification>? seed,
}) async {
  final viewModel = NotificationsViewModel(
    initialNotifications: seed ?? _seed(),
  );
  addTearDown(viewModel.dispose);
  await tester.pumpWidget(
    MaterialApp(home: NotificationsPage(viewModel: viewModel)),
  );
  await tester.pumpAndSettle();
  return viewModel;
}

void main() {
  testWidgets(
    'filtra por estado de lectura y omite filtros por tipo y píldora en header',
    (tester) async {
      await _pumpPage(tester);

      expect(find.text('Todos los tipos'), findsNothing);
      expect(find.text('2 sin leer'), findsNothing);
      expect(find.text('Al día'), findsNothing);

      expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(find.text('Recordatorio de entrenamiento'), findsOneWidget);

      await tester.tap(find.text('No leídas'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(find.text('Recordatorio de entrenamiento'), findsNothing);

      await tester.tap(find.text('Leídas'));
      await tester.pumpAndSettle();
      expect(find.text('Recordatorio de entrenamiento'), findsOneWidget);
      expect(find.text('Nuevo inicio de sesión'), findsNothing);

      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(find.text('Recordatorio de entrenamiento'), findsOneWidget);
    },
  );

  testWidgets('alterna isRead al tocar la notificación y marca todas leídas', (
    tester,
  ) async {
    final viewModel = await _pumpPage(tester);

    expect(
      find.byKey(const Key('notification-unread-dot-n-login')),
      findsOneWidget,
    );
    expect(viewModel.unreadCount, 2);

    await tester.tap(find.text('Nuevo inicio de sesión'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notification-unread-dot-n-login')),
      findsNothing,
    );
    expect(viewModel.unreadCount, 1);

    // Vuelve a marcar como no leída desde el botón de acción de la tarjeta.
    await tester.tap(find.byTooltip('Marcar como no leída').first);
    await tester.pumpAndSettle();
    expect(viewModel.unreadCount, 2);

    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pumpAndSettle();

    expect(viewModel.unreadCount, 0);
    expect(find.text('Al día'), findsNothing);
    expect(
      find.byKey(const Key('notification-unread-dot-n-login')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('notification-unread-dot-n-password')),
      findsNothing,
    );
  });

  testWidgets('elimina una notificación con gesto Dismissible', (tester) async {
    final viewModel = await _pumpPage(tester);

    expect(find.byType(Dismissible), findsNWidgets(3));

    await tester.drag(
      find.byKey(const ValueKey('n-login')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nuevo inicio de sesión'), findsNothing);
    expect(viewModel.notifications.map((n) => n.id), [
      'n-password',
      'n-reminder',
    ]);
  });

  testWidgets('muestra estado vacío diferenciado por filtro y limpia filtros', (
    tester,
  ) async {
    await _pumpPage(tester);

    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No leídas'));
    await tester.pumpAndSettle();

    expect(find.text('Sin resultados con este filtro'), findsOneWidget);
    expect(find.text('Sin notificaciones'), findsNothing);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
    expect(find.text('Recordatorio de entrenamiento'), findsOneWidget);
  });

  testWidgets('botón Eliminar todas vacía la lista y muestra estado vacío', (
    tester,
  ) async {
    final viewModel = await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('notifications-delete-all')));
    await tester.pumpAndSettle();

    expect(viewModel.isEmpty, isTrue);
    expect(find.text('Sin notificaciones'), findsOneWidget);
    expect(find.text('Sin resultados con este filtro'), findsNothing);
  });

  testWidgets('no desborda en ancho móvil de 360dp', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Eliminar todas'), findsOneWidget);
  });

  group('estados remotos y mutaciones (W13-6)', () {
    testWidgets(
      'estado AsyncLoading muestra CircularProgressIndicator y luego carga',
      (tester) async {
        final completer = Completer<List<AppNotification>>();
        final repository = _FakeNotificationsRepository()
          ..fetchCompleter = completer;
        final viewModel = NotificationsViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(home: NotificationsPage(viewModel: viewModel)),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(repository.fetchCalls, 1);

        completer.complete(_seed());
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
      },
    );

    testWidgets(
      'estado AsyncError muestra mensaje y pulsar Reintentar invoca load',
      (tester) async {
        final repository = _FakeNotificationsRepository(seed: _seed())
          ..fetchError = Exception('sin red');
        final viewModel = NotificationsViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(home: NotificationsPage(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        expect(repository.fetchCalls, 1);
        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
        expect(
          find.text('No pudimos cargar tus notificaciones'),
          findsOneWidget,
        );
        expect(
          find.text('Verifica tu conexión e intenta nuevamente.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);

        repository.fetchError = null;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(repository.fetchCalls, 2);
        expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
      },
    );

    testWidgets(
      'fallo en toggleRead revierte el estado de la tarjeta y muestra SnackBar',
      (tester) async {
        final repository = _FakeNotificationsRepository(seed: _seed())
          ..updateError = Exception('sin red');
        final viewModel = NotificationsViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(home: NotificationsPage(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('notification-unread-dot-n-login')),
          findsOneWidget,
        );
        expect(viewModel.unreadCount, 2);

        await tester.tap(find.text('Nuevo inicio de sesión'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('notification-unread-dot-n-login')),
          findsOneWidget,
        );
        expect(viewModel.unreadCount, 2);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(notificationMutationErrorMessage), findsOneWidget);
        expect(viewModel.mutationError, isNull);
      },
    );

    testWidgets(
      'fallo en deleteNotification revierte la tarjeta y muestra SnackBar',
      (tester) async {
        final repository = _FakeNotificationsRepository(seed: _seed())
          ..deleteError = Exception('sin red');
        final viewModel = NotificationsViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(home: NotificationsPage(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const ValueKey('n-login')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Nuevo inicio de sesión'), findsOneWidget);
        expect(viewModel.notifications.map((n) => n.id), [
          'n-login',
          'n-password',
          'n-reminder',
        ]);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(notificationMutationErrorMessage), findsOneWidget);
        expect(viewModel.mutationError, isNull);
      },
    );
  });
}

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository({List<AppNotification>? seed})
    : _items = List<AppNotification>.of(seed ?? const []);

  final List<AppNotification> _items;
  Completer<List<AppNotification>>? fetchCompleter;
  Object? fetchError;
  Object? updateError;
  Object? deleteError;
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
    return Future.value(List<AppNotification>.unmodifiable(_items));
  }

  @override
  Future<int> fetchUnreadCount() =>
      Future.value(_items.where((item) => !item.isRead).length);

  @override
  Future<AppNotification?> updateRead(String id, {required bool isRead}) {
    if (updateError != null) return Future.error(updateError!);
    AppNotification? updated;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].id != id) continue;
      updated = _items[i].copyWith(isRead: isRead, clearReadAt: !isRead);
      _items[i] = updated;
    }
    return Future.value(updated);
  }

  @override
  Future<void> markAllAsRead() async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
  }

  @override
  Future<void> deleteNotification(String id) {
    if (deleteError != null) return Future.error(deleteError!);
    _items.removeWhere((item) => item.id == id);
    return Future<void>.value();
  }

  @override
  Future<void> deleteAll() async => _items.clear();
}
