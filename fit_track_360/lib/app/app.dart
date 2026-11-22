import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../design_system/tokens/app_colors.dart';
import '../features/notifications/data/push_device_lifecycle_service.dart';
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
  const FitTrackApp({super.key, this.pushDeviceService});

  /// Inyectable en pruebas; en runtime se crea una sola instancia compartida.
  final PushDeviceLifecycle? pushDeviceService;

  @override
  State<FitTrackApp> createState() => _FitTrackAppState();
}

class _FitTrackAppState extends State<FitTrackApp> {
  ApiClient? _ownedClient;
  late final PushDeviceLifecycle _pushDeviceService;
  late final bool _ownsPushDeviceService;

  @override
  void initState() {
    super.initState();
    final injected = widget.pushDeviceService;
    _ownsPushDeviceService = injected == null;
    if (injected != null) {
      _pushDeviceService = injected;
      return;
    }
    final client = ApiClient();
    _ownedClient = client;
    _pushDeviceService = PushDeviceLifecycleService.fromClient(client);
  }

  @override
  void dispose() {
    if (_ownsPushDeviceService) {
      unawaited(_pushDeviceService.dispose());
    }
    _ownedClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PushDeviceScope(
      service: _pushDeviceService,
      child: MaterialApp.router(
        themeMode: ThemeMode.dark,
        theme: fitTrackDarkTheme,
        darkTheme: fitTrackDarkTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
