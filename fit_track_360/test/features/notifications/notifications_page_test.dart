import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
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
}
