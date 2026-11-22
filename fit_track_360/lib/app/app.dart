import 'package:flutter/material.dart';

import '../design_system/tokens/app_colors.dart';
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
  const FitTrackApp({super.key});

  @override
  State<FitTrackApp> createState() => _FitTrackAppState();
}

class _FitTrackAppState extends State<FitTrackApp> {
  final NotificationsViewModel _notifications = NotificationsViewModel();

  @override
  void dispose() {
    _notifications.dispose();
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
