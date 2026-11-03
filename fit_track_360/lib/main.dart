import 'package:flutter/material.dart';

import 'app/router.dart';
import 'design_system/tokens/app_colors.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: ColorScheme.dark(
          surface: AppColors.bgDeep,
          primary: AppColors.accentWhite,
          onPrimary: AppColors.textOnAccent,
          onSurface: AppColors.textPrimary,
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
