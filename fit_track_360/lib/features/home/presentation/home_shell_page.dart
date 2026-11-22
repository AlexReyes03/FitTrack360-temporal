import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/session_storage.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../auth/data/logout_service.dart';
import '../data/dashboard_api_repository.dart';
import '../data/pedometer_steps_sensor.dart';
import '../domain/steps_sensor.dart';
import 'home_dashboard_view_model.dart';
import 'widgets/dashboard_block_shell.dart';
import 'widgets/dashboard_metric_card.dart';
import 'widgets/dashboard_nutrition_card.dart';
import 'widgets/dashboard_session_card.dart';
import 'widgets/dashboard_steps_card.dart';
import 'widgets/home_dashboard_content.dart';
import 'widgets/glass_bottom_nav_bar.dart';
import 'widgets/home_navigation_shell.dart';
import 'widgets/quick_actions_row.dart';

/// Shell post-login. Carga el perfil con el cliente HTTP y cierra sesion
/// (Firebase + revocacion Nest), volviendo a login.
/// Muestra [OfflineBanner] sin red y recarga el perfil + dashboard al
/// recuperarla.
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({
    super.key,
    this.apiClient,
    this.sessionStorage,
    this.connectivityService,
    this.dashboardViewModel,
    this.stepsSensor,
  });

  /// Dependencias sustituibles en pruebas; por defecto usa las reales.
  final ApiClient? apiClient;
  final SessionStorage? sessionStorage;
  final ConnectivityService? connectivityService;
  final HomeDashboardViewModel? dashboardViewModel;
  final StepsSensor? stepsSensor;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  late final SessionStorage _storage =
      widget.sessionStorage ?? appSessionStorage;
  late final ApiClient _api = widget.apiClient ?? ApiClient(storage: _storage);
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  late final HomeDashboardViewModel _dashboard;
  late final bool _ownsDashboard;
  StreamSubscription<bool>? _connectivitySubscription;

  String? _displayName;
  bool _loggingOut = false;
  bool _loadingProfile = false;

  /// Evita navegar dos veces a login cuando perfil y dashboard expiran juntos.
  bool _redirectingToLogin = false;

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
    _loadProfile();
    unawaited(_dashboard.load());
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
    _dashboard.removeListener(_onDashboardChanged);
    if (_ownsDashboard) {
      _dashboard.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    // Dos cargas simultaneas con ID token vencido fuerzan un solo refresh.
    if (_loadingProfile || _loggingOut) return;
    _loadingProfile = true;
    try {
      final profile = await _api.me();
      if (!mounted) return;
      setState(() => _displayName = profile.displayName);
    } on SessionExpiredException {
      _goToLogin();
    } catch (_) {
      // Sin red o perfil no disponible: se mantiene el saludo generico.
    } finally {
      _loadingProfile = false;
    }
  }

  Future<void> _retryAll() async {
    await Future.wait([_loadProfile(), _dashboard.load()]);
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await LogoutService(storage: _storage).logout();
    _goToLogin();
  }

  static const List<GlassNavDestination> _destinations = [
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
      icon: Icons.photo_camera_outlined,
      selectedIcon: Icons.photo_camera_rounded,
    ),
    GlassNavDestination(
      label: 'Perfil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  void _onDestinationSelected(int index) {
    switch (index) {
      case 0:
        return;
      case 1:
        context.push('/app/entrenamientos');
      case 2:
        context.push('/app/comidas');
      case 3:
        context.push('/app/ejercicios');
      case 4:
        context.push('/app/progreso');
      case 5:
        context.push('/app/perfil');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeNavigationShell(
      topBanner: OfflineBanner(service: _connectivity, onRetry: _retryAll),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: _Header(onProfileTap: () => context.push('/app/perfil')),
      ),
      destinations: _destinations,
      selectedIndex: 0,
      onDestinationSelected: _onDestinationSelected,
      body: ListenableBuilder(
        listenable: _dashboard,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
                      _dashboard.steps.dataOrNull ?? DashboardStepsData.preview,
                  stepsUnavailable: _dashboard.stepsUnavailable,
                  stepsUnavailableReason: _dashboard.stepsUnavailableReason,
                  stepsNeedPermission: _dashboard.stepsNeedPermission,
                  stepsCanOpenSettings: _dashboard.stepsCanOpenSettings,
                  onRetrySteps: _dashboard.retrySteps,
                  onEnableSteps: _dashboard.enableSteps,
                  onOpenStepsSettings: () =>
                      unawaited(_dashboard.openStepsSettings()),
                  onOpenWorkout: () => context.push('/app/entrenamientos'),
                  onOpenMeals: () => context.push('/app/comidas'),
                  onOpenPhoto: () => context.push('/app/foto'),
                ),
                const SizedBox(height: 18),
                // Acceso extra no cubierto por DashboardQuickActions (W11-12).
                QuickActionsRow(
                  title: null,
                  actions: [
                    QuickActionItem(
                      label: 'Tracker diario',
                      subtitle: 'Próximamente',
                      icon: Icons.insights_rounded,
                      onTap: () => context.push('/app/tracker'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
        child: PrimaryButton(
          label: _loggingOut ? 'Cerrando...' : 'Cerrar sesión',
          onPressed: _loggingOut ? null : _logout,
        ),
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

class _Header extends StatelessWidget {
  final VoidCallback onProfileTap;

  const _Header({required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.accentWhite, AppColors.textSecondary],
            ),
            boxShadow: [BoxShadow(color: Color(0xCCFFFFFF), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'FITTRACK360',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Perfil',
          onPressed: onProfileTap,
          icon: const Icon(
            Icons.person_outline,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
