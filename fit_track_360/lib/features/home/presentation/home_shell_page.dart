import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/session_storage.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../notifications/data/push_device_lifecycle_service.dart';
import '../../notifications/presentation/push_device_scope.dart';
import '../data/dashboard_api_repository.dart';
import '../data/pedometer_steps_sensor.dart';
import '../domain/steps_sensor.dart';
import 'home_dashboard_view_model.dart';
import 'widgets/app_shell_tab_scope.dart';
import 'widgets/dashboard_block_shell.dart';
import 'widgets/dashboard_metric_card.dart';
import 'widgets/dashboard_nutrition_card.dart';
import 'widgets/dashboard_session_card.dart';
import 'widgets/dashboard_steps_card.dart';
import 'widgets/home_dashboard_content.dart';
import 'widgets/quick_actions_row.dart';

/// Vista de Inicio dentro del shell persistente.
///
/// Carga el perfil con el cliente HTTP y muestra el dashboard. El cierre de
/// sesión vive en Perfil. Muestra [OfflineBanner] sin red y recarga el perfil
/// y el dashboard al recuperarla, al deslizar hacia abajo y al volver a la
/// pestaña Inicio desde otra (vía [AppShellTabScope]).
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({
    super.key,
    this.apiClient,
    this.sessionStorage,
    this.connectivityService,
    this.dashboardViewModel,
    this.stepsSensor,
    this.pushDeviceService,
  });

  /// Dependencias sustituibles en pruebas; por defecto usa las reales.
  final ApiClient? apiClient;
  final SessionStorage? sessionStorage;
  final ConnectivityService? connectivityService;
  final HomeDashboardViewModel? dashboardViewModel;
  final StepsSensor? stepsSensor;
  final PushDeviceLifecycle? pushDeviceService;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  late final SessionStorage _storage =
      widget.sessionStorage ?? appSessionStorage;
  late final ApiClient _api = widget.apiClient ?? ApiClient(storage: _storage);
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  PushDeviceLifecycle? _pushDeviceService;
  PushDeviceLifecycle? _ownedPushDeviceService;
  bool _didInitializeDependencies = false;
  late final HomeDashboardViewModel _dashboard;
  late final bool _ownsDashboard;
  StreamSubscription<bool>? _connectivitySubscription;
  ValueListenable<int>? _shellTab;
  int? _lastShellTab;

  String? _displayName;
  bool _loadingProfile = false;

  /// Evita navegar dos veces a login cuando perfil y dashboard expiran juntos.
  bool _redirectingToLogin = false;

  PushDeviceLifecycle _resolvePushDeviceService() {
    final resolved = _pushDeviceService;
    if (resolved != null) return resolved;
    final service =
        widget.pushDeviceService ??
        PushDeviceScope.maybeOf(context) ??
        (_ownedPushDeviceService = PushDeviceLifecycleService.fromClient(
          _api,
          storage: _storage,
        ));
    _pushDeviceService = service;
    return service;
  }

  @override
  void initState() {
    super.initState();
    if (widget.dashboardViewModel != null) {
      _dashboard = widget.dashboardViewModel!;
      _ownsDashboard = false;
    } else {
      _dashboard = HomeDashboardViewModel(
        repository: DashboardApiRepository.fromClient(_api),
        stepsSensor: widget.stepsSensor ?? PedometerStepsSensor(),
      );
      _ownsDashboard = true;
    }
    _dashboard.addListener(_onDashboardChanged);
    _connectivitySubscription = _connectivity.onStatusChange.listen((online) {
      if (online) {
        if (_displayName == null) _loadProfile();
        unawaited(_dashboard.load());
      }
    }, onError: (_) {});
    unawaited(_dashboard.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeDependencies) return;
    _didInitializeDependencies = true;
    _resolvePushDeviceService();
    _loadProfile();
    final shellTab = _shellTab = AppShellTabScope.maybeOf(context);
    if (shellTab != null) {
      _lastShellTab = shellTab.value;
      shellTab.addListener(_onShellTabChanged);
    }
  }

  /// Al regresar a Inicio desde otra pestaña refresca perfil y resumen, por si
  /// el usuario registró una comida, un entrenamiento o cambió sus metas.
  void _onShellTabChanged() {
    final tab = _shellTab?.value;
    final previous = _lastShellTab;
    _lastShellTab = tab;
    if (tab == appShellHomeTabIndex && previous != appShellHomeTabIndex) {
      unawaited(_refreshAll());
    }
  }

  void _onDashboardChanged() {
    if (_dashboard.sessionExpired) _goToLogin();
  }

  void _goToLogin() {
    if (_redirectingToLogin || !mounted) return;
    _redirectingToLogin = true;
    context.go('/login');
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _shellTab?.removeListener(_onShellTabChanged);
    _dashboard.removeListener(_onDashboardChanged);
    if (_ownsDashboard) {
      _dashboard.dispose();
    }
    final ownedPush = _ownedPushDeviceService;
    if (ownedPush != null) {
      unawaited(ownedPush.dispose());
    }
    _api.dispose();
    super.dispose();
  }

  /// [syncPush] en `false` solo actualiza el saludo: al refrescar (deslizar o
  /// volver a Inicio) el ciclo de vida FCM sigue en manos de Perfil.
  Future<void> _loadProfile({bool syncPush = true}) async {
    // Dos cargas simultaneas con ID token vencido fuerzan un solo refresh.
    if (_loadingProfile) return;
    _loadingProfile = true;
    try {
      final profile = await _api.me();
      if (!mounted) return;
      setState(() => _displayName = profile.displayName);
      if (syncPush) {
        unawaited(_syncPushSilently(profile.notificationsEnabled));
      }
    } on SessionExpiredException {
      _goToLogin();
    } catch (_) {
      // Sin red o perfil no disponible: se mantiene el saludo generico.
    } finally {
      _loadingProfile = false;
    }
  }

  Future<void> _syncPushSilently(bool notificationsEnabled) async {
    try {
      await _resolvePushDeviceService().syncForActiveSession(
        notificationsEnabled: notificationsEnabled,
        requestPermissionIfNeeded: false,
      );
    } catch (_) {
      // Sin Play Services, APNs o red: se degrada en silencio.
    }
  }

  Future<void> _retryAll() async {
    await Future.wait([_loadProfile(), _dashboard.load()]);
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadProfile(syncPush: false), _dashboard.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OfflineBanner(service: _connectivity, onRetry: _retryAll),
          Expanded(
            child: ListenableBuilder(
              listenable: _dashboard,
              builder: (context, _) {
                return RefreshIndicator(
                  onRefresh: _refreshAll,
                  color: AppColors.accentWhite,
                  backgroundColor: AppColors.bgMid,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HomeDashboardContent(
                          displayName: _displayName,
                          nutritionStatus: _blockStatus(_dashboard.nutrition),
                          nutritionData:
                              _dashboard.nutrition.dataOrNull ??
                              DashboardNutritionData.preview,
                          onRetryNutrition: _dashboard.load,
                          sessionStatus: _blockStatus(_dashboard.session),
                          sessionData:
                              _dashboard.session.dataOrNull ??
                              DashboardSessionData.preview,
                          onRetrySession: _dashboard.load,
                          metricStatus: _blockStatus(_dashboard.metric),
                          metricData:
                              _dashboard.metric.dataOrNull ??
                              DashboardMetricData.preview,
                          onRetryMetric: _dashboard.load,
                          stepsStatus: _blockStatus(_dashboard.steps),
                          stepsData:
                              _dashboard.steps.dataOrNull ??
                              DashboardStepsData.preview,
                          stepsUnavailable: _dashboard.stepsUnavailable,
                          stepsUnavailableReason:
                              _dashboard.stepsUnavailableReason,
                          stepsNeedPermission: _dashboard.stepsNeedPermission,
                          stepsCanOpenSettings: _dashboard.stepsCanOpenSettings,
                          onRetrySteps: _dashboard.retrySteps,
                          onEnableSteps: _dashboard.enableSteps,
                          onOpenStepsSettings: () =>
                              unawaited(_dashboard.openStepsSettings()),
                          onOpenWorkout: () =>
                              context.go('/app/entrenamientos'),
                          onOpenMeals: () => context.go('/app/comidas'),
                          onOpenPhoto: () => context.push('/app/foto'),
                          onOpenProgress: () => context.go('/app/progreso'),
                        ),
                        const SizedBox(height: 18),
                        // Accesos al tracker y a Rutinas, no cubiertos por
                        // DashboardQuickActions (#228).
                        QuickActionsRow(
                          title: null,
                          actions: [
                            QuickActionItem(
                              label: 'Entrenar ahora',
                              subtitle: 'Registra tus series en vivo',
                              icon: Icons.timer_outlined,
                              onTap: () => context.push('/app/tracker'),
                            ),
                            QuickActionItem(
                              label: 'Rutinas',
                              subtitle: 'Entrena con tus plantillas',
                              icon: Icons.list_alt_rounded,
                              onTap: () => context.push('/app/rutinas'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

DashboardBlockStatus _blockStatus<T>(AsyncState<T> state) {
  return switch (state) {
    AsyncLoading<T>() => DashboardBlockStatus.loading,
    AsyncError<T>() => DashboardBlockStatus.error,
    AsyncEmpty<T>() => DashboardBlockStatus.empty,
    AsyncData<T>() => DashboardBlockStatus.data,
  };
}
