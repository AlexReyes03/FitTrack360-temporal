import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/session_storage.dart';
import '../design_system/tokens/app_colors.dart';
import '../features/notifications/data/notifications_api_repository.dart';
import '../features/notifications/data/push_device_lifecycle_service.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import '../features/notifications/presentation/notifications_view_model.dart';
import '../features/notifications/presentation/push_device_scope.dart';
import 'router.dart';

final ThemeData fitTrackDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bgDeep,
  colorScheme: const ColorScheme.dark(
    surface: AppColors.bgDeep,
    primary: AppColors.accentWhite,
    onPrimary: AppColors.textOnAccent,
    onSurface: AppColors.textPrimary,
  ),
);

class FitTrackApp extends StatefulWidget {
  const FitTrackApp({super.key, this.notifications, this.pushDeviceService});

  /// Inyectable en pruebas; en runtime se crea con el API real.
  final NotificationsViewModel? notifications;

  /// Inyectable en pruebas; en runtime se crea una sola instancia compartida.
  final PushDeviceLifecycle? pushDeviceService;

  @override
  State<FitTrackApp> createState() => _FitTrackAppState();
}

class _FitTrackAppState extends State<FitTrackApp> {
  ApiClient? _apiClient;
  late final NotificationsViewModel _notifications;
  late final bool _ownsNotifications;
  late final PushDeviceLifecycle _pushDeviceService;
  late final bool _ownsPushDeviceService;

  ApiClient _ensureApiClient() => _apiClient ??= ApiClient();

  @override
  void initState() {
    super.initState();
    final injectedNotifications = widget.notifications;
    _ownsNotifications = injectedNotifications == null;
    if (injectedNotifications != null) {
      _notifications = injectedNotifications;
    } else {
      _notifications = NotificationsViewModel(
        repository: NotificationsApiRepository(_ensureApiClient()),
      );
    }

    final injectedPush = widget.pushDeviceService;
    _ownsPushDeviceService = injectedPush == null;
    if (injectedPush != null) {
      _pushDeviceService = injectedPush;
    } else {
      _pushDeviceService = PushDeviceLifecycleService.fromClient(
        _ensureApiClient(),
      );
    }

    appSessionInvalidations.addListener(_onSessionInvalidated);
  }

  /// Una sesión expirada o cerrada no debe dejar avisos de la cuenta anterior.
  void _onSessionInvalidated() => _notifications.clearOnLogout();

  @override
  void dispose() {
    appSessionInvalidations.removeListener(_onSessionInvalidated);
    if (_ownsNotifications) _notifications.dispose();
    if (_ownsPushDeviceService) {
      unawaited(_pushDeviceService.dispose());
    }
    _apiClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PushDeviceScope(
      service: _pushDeviceService,
      child: NotificationsScope(
        notifier: _notifications,
        child: MaterialApp.router(
          themeMode: ThemeMode.dark,
          theme: fitTrackDarkTheme,
          darkTheme: fitTrackDarkTheme,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
