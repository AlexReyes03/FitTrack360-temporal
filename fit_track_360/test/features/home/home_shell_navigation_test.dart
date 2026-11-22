import 'package:fit_track_360/design_system/components/app_logo.dart';
import 'package:fit_track_360/features/home/presentation/app_shell_page.dart';
import 'package:fit_track_360/features/home/presentation/widgets/app_shell_header.dart';
import 'package:fit_track_360/features/home/presentation/widgets/glass_bottom_nav_bar.dart';
import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_page.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_scope.dart';
import 'package:fit_track_360/features/notifications/presentation/notifications_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

NotificationsViewModel _notifications() {
  return NotificationsViewModel(
    initialNotifications: [
      AppNotification(
        id: 'unread-login',
        title: 'Nuevo inicio de sesión',
        message: 'Se inició sesión en otro dispositivo.',
        type: AppNotificationType.newLogin,
        createdAt: DateTime(2026, 11, 22, 10),
      ),
      AppNotification(
        id: 'unread-reminder',
        title: 'Recordatorio de entrenamiento',
        message: 'Registra tu sesión de hoy.',
        type: AppNotificationType.reminder,
        createdAt: DateTime(2026, 11, 22, 9),
      ),
      AppNotification(
        id: 'read-password',
        title: 'Contraseña actualizada',
        message: 'Tu contraseña se cambió correctamente.',
        type: AppNotificationType.passwordChanged,
        createdAt: DateTime(2026, 11, 21, 18),
        isRead: true,
      ),
    ],
  );
}

GoRouter _shellRouter() {
  return GoRouter(
    initialLocation: '/app',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellPage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app',
                builder: (context, state) => const Text('vista-inicio'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/entrenamientos',
                builder: (context, state) => const Text('vista-entrenamientos'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/comidas',
                builder: (context, state) => const Text('vista-comidas'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/ejercicios',
                builder: (context, state) => const Text('vista-ejercicios'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/progreso',
                builder: (context, state) => const Text('vista-progreso'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/perfil',
                builder: (context, state) => const Text('vista-perfil'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/app/notificaciones',
        builder: (context, state) => const NotificationsPage(),
      ),
    ],
  );
}

Future<NotificationsViewModel> _pump(
  WidgetTester tester,
  GoRouter router,
) async {
  final notifications = _notifications();
  addTearDown(notifications.dispose);
  await tester.pumpWidget(
    NotificationsScope(
      notifier: notifications,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return notifications;
}

void main() {
  testWidgets('las 6 vistas principales comparten el shell y la barra', (
    tester,
  ) async {
    final router = _shellRouter();
    await _pump(tester, router);

    expect(find.text('vista-inicio'), findsOneWidget);
    expect(find.byType(GlassBottomNavBar), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsNothing);

    for (final (label, marker) in [
      ('Entrenos', 'vista-entrenamientos'),
      ('Comidas', 'vista-comidas'),
      ('Ejercicios', 'vista-ejercicios'),
      ('Progreso', 'vista-progreso'),
      ('Perfil', 'vista-perfil'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(marker), findsOneWidget, reason: label);
      expect(
        find.byType(GlassBottomNavBar),
        findsOneWidget,
        reason: 'La barra debe seguir visible en $label',
      );
    }

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('vista-inicio'), findsOneWidget);
  });

  testWidgets('la campana muestra el badge y abre notificaciones', (
    tester,
  ) async {
    final router = _shellRouter();
    final notifications = await _pump(tester, router);

    expect(notifications.unreadCount, 2);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Marcar todas como leídas'), findsOneWidget);
    expect(find.text('Nuevo inicio de sesión'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('vista-inicio'), findsOneWidget);
  });

  testWidgets(
    'en 360dp muestra header con AppLogo y navbar sin desbordar en las 6 vistas',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final router = _shellRouter();
      await _pump(tester, router);

      expect(find.byType(AppShellHeader), findsOneWidget);
      expect(find.byType(AppLogo), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final (label, marker) in [
        ('Inicio', 'vista-inicio'),
        ('Entrenos', 'vista-entrenamientos'),
        ('Comidas', 'vista-comidas'),
        ('Ejercicios', 'vista-ejercicios'),
        ('Progreso', 'vista-progreso'),
        ('Perfil', 'vista-perfil'),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(marker), findsOneWidget, reason: label);
        expect(
          find.byType(GlassBottomNavBar),
          findsOneWidget,
          reason: 'GlassBottomNavBar visible en $label',
        );
        expect(
          find.text('Cerrar sesión'),
          findsNothing,
          reason: 'No debe existir botón global de Cerrar sesión en $label',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Sin overflow en $label',
        );
      }
    },
  );
}
