import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../notifications/data/push_device_lifecycle_service.dart';
import '../../notifications/presentation/notifications_scope.dart';
import '../../notifications/presentation/push_device_scope.dart';
import 'widgets/app_shell_header.dart';
import 'widgets/app_shell_tab_scope.dart';
import 'widgets/glass_bottom_nav_bar.dart';
import 'widgets/home_navigation_shell.dart';

/// Destinos de las 6 vistas principales. El orden debe coincidir con el de las
/// ramas de `StatefulShellRoute` en `router.dart`.
const List<GlassNavDestination> appShellDestinations = [
  GlassNavDestination(
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  GlassNavDestination(
    label: 'Entrenos',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center_rounded,
  ),
  GlassNavDestination(
    label: 'Comidas',
    icon: Icons.restaurant_outlined,
    selectedIcon: Icons.restaurant_rounded,
  ),
  GlassNavDestination(
    label: 'Ejercicios',
    icon: Icons.sports_gymnastics_outlined,
    selectedIcon: Icons.sports_gymnastics_rounded,
  ),
  GlassNavDestination(
    label: 'Progreso',
    icon: Icons.trending_up_outlined,
    selectedIcon: Icons.trending_up_rounded,
  ),
  GlassNavDestination(
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// Shell persistente de la app autenticada.
///
/// Recibe el [StatefulNavigationShell] del router, dibuja el header global y la
/// barra inferior, y deja que cada rama conserve su propio estado y navegador.
/// El cierre de sesión vive solo en Perfil.
class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.navigationShell,
    this.pushDeviceService,
  });

  final StatefulNavigationShell navigationShell;

  /// Inyectable en pruebas; en runtime hereda [PushDeviceScope] desde la app.
  final PushDeviceLifecycle? pushDeviceService;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  bool _didInitializeDependencies = false;
  ApiClient? _ownedClient;
  PushDeviceLifecycle? _pushDeviceService;
  PushDeviceLifecycle? _ownedPushDeviceService;
  bool _providesPushDeviceScope = false;
  late final ValueNotifier<int> _currentTab = ValueNotifier(
    widget.navigationShell.currentIndex,
  );

  @override
  void didUpdateWidget(AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.navigationShell.currentIndex;
    if (index == _currentTab.value) return;
    // Se publica tras el frame: los oyentes (Inicio) pueden recargar y
    // notificar sin marcar widgets durante el build del shell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _currentTab.value = widget.navigationShell.currentIndex;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeDependencies) return;
    _didInitializeDependencies = true;

    final ambientPush = PushDeviceScope.maybeOf(context);
    if (widget.pushDeviceService != null) {
      _pushDeviceService = widget.pushDeviceService;
      _providesPushDeviceScope = true;
    } else if (ambientPush != null) {
      _pushDeviceService = ambientPush;
      _providesPushDeviceScope = false;
    } else {
      final client = _ownedClient = ApiClient();
      final owned = _ownedPushDeviceService =
          PushDeviceLifecycleService.fromClient(client);
      _pushDeviceService = owned;
      _providesPushDeviceScope = true;
    }

    final notifications = NotificationsScope.maybeOf(context);
    if (notifications != null) {
      scheduleMicrotask(() {
        if (!mounted) return;
        if (notifications.sessionExpired) {
          notifications.clearOnLogout();
        }
        unawaited(notifications.refreshUnreadCount());
      });
    }
  }

  @override
  void dispose() {
    final ownedPush = _ownedPushDeviceService;
    if (ownedPush != null) {
      unawaited(ownedPush.dispose());
    }
    _ownedClient?.dispose();
    _currentTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationsScope.maybeOf(context);
    final shell = HomeNavigationShell(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 4),
        child: AppShellHeader(
          unreadCount: notifications?.unreadCount ?? 0,
          onNotificationsTap: () => context.push('/app/notificaciones'),
        ),
      ),
      destinations: appShellDestinations,
      selectedIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: (index) => widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      ),
      body: AppShellTabScope(
        currentTab: _currentTab,
        child: widget.navigationShell,
      ),
    );
    if (_providesPushDeviceScope && _pushDeviceService != null) {
      return PushDeviceScope(service: _pushDeviceService!, child: shell);
    }
    return shell;
  }
}
