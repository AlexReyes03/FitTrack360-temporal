import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../design_system/tokens/app_colors.dart';
import '../features/notifications/data/notifications_api_repository.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import '../features/notifications/presentation/notifications_view_model.dart';
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
  const FitTrackApp({super.key, this.notifications});

  /// Inyectable en pruebas; en runtime se crea con el API real.
  final NotificationsViewModel? notifications;

  @override
  State<FitTrackApp> createState() => _FitTrackAppState();
}

class _FitTrackAppState extends State<FitTrackApp> {
  ApiClient? _apiClient;
  late final NotificationsViewModel _notifications;
  late final bool _ownsNotifications;

  @override
  void initState() {
    super.initState();
    final injected = widget.notifications;
    _ownsNotifications = injected == null;
    if (injected != null) {
      _notifications = injected;
      return;
    }
    final client = ApiClient();
    _apiClient = client;
    _notifications = NotificationsViewModel(
      repository: NotificationsApiRepository(client),
    );
  }

  @override
  void dispose() {
    if (_ownsNotifications) _notifications.dispose();
    _apiClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationsScope(
      notifier: _notifications,
      child: MaterialApp.router(
        themeMode: ThemeMode.dark,
        theme: fitTrackDarkTheme,
        darkTheme: fitTrackDarkTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
