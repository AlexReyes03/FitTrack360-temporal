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
import '../../../design_system/widgets/app_background.dart';
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
    if (_dashboard.sessionExpired && mounted) {
      context.go('/login');
    }
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
      if (!mounted) return;
      context.go('/login');
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
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OfflineBanner(service: _connectivity, onRetry: _retryAll),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: _Header(
                      onProfileTap: () => context.push('/app/perfil'),
                    ),
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _dashboard,
                      builder: (context, _) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: HomeDashboardContent(
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
                            onRetrySteps: _dashboard.load,
                            onOpenWorkout: () =>
                                context.push('/app/entrenamientos'),
                            onOpenMeals: () => context.push('/app/comidas'),
                            onOpenPhoto: () => context.push('/app/foto'),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    // Wrap evita el desborde del Row con tres accesos en
                    // pantallas estrechas.
                    child: Wrap(
                      children: [
                        TextButton(
                          onPressed: () => context.push('/app/foto'),
                          child: const Text(
                            'Agregar foto',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/app/entrenamientos'),
                          child: const Text(
                            'Entrenamientos',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/app/ejercicios'),
                          child: const Text(
                            'Ejercicios',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/app/comidas'),
                          child: const Text(
                            'Comidas',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/app/perfil'),
                          child: const Text(
                            'Perfil',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: PrimaryButton(
                      label: _loggingOut ? 'Cerrando...' : 'Cerrar sesión',
                      onPressed: _loggingOut ? null : _logout,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
