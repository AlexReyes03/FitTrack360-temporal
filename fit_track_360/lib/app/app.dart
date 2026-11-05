import 'package:flutter/material.dart';

import '../design_system/tokens/app_colors.dart';
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

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      themeMode: ThemeMode.dark,
      theme: fitTrackDarkTheme,
      darkTheme: fitTrackDarkTheme,
      routerConfig: appRouter,
    );
  }
}
