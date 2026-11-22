import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/session_storage.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../design_system/components/glass_surface.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../auth/data/logout_service.dart';
import 'widgets/glass_bottom_nav_bar.dart';
import 'widgets/home_navigation_shell.dart';
import 'widgets/quick_actions_row.dart';

/// Shell post-login. Carga el perfil con el cliente HTTP y cierra sesion
/// (Firebase + revocacion Nest), volviendo a login.
/// Muestra [OfflineBanner] sin red y recarga el perfil al recuperarla.
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({
    super.key,
    this.apiClient,
    this.sessionStorage,
    this.connectivityService,
  });

  /// Dependencias sustituibles en pruebas; por defecto usa las reales.
  final ApiClient? apiClient;
  final SessionStorage? sessionStorage;
  final ConnectivityService? connectivityService;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  late final SessionStorage _storage =
      widget.sessionStorage ?? appSessionStorage;
  late final ApiClient _api = widget.apiClient ?? ApiClient(storage: _storage);
  late final ConnectivityService _connectivity =
      widget.connectivityService ?? ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;

  String? _displayName;
  bool _loggingOut = false;
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = _connectivity.onStatusChange.listen((online) {
      if (online && _displayName == null) _loadProfile();
    }, onError: (_) {});
    _loadProfile();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
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

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await LogoutService(storage: _storage).logout();
    if (!mounted) return;
    context.go('/login');
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
        context.push('/app/foto');
      case 5:
        context.push('/app/perfil');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeNavigationShell(
      topBanner: OfflineBanner(service: _connectivity, onRetry: _loadProfile),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: _Header(onProfileTap: () => context.push('/app/perfil')),
      ),
      destinations: _destinations,
      selectedIndex: 0,
      onDestinationSelected: _onDestinationSelected,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _displayName == null
                        ? 'Hola, bienvenido'
                        : 'Hola, $_displayName',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aqui va tu resumen de entrenamientos, comidas y progreso.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.035),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Contenido proximo',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            QuickActionsRow(
              actions: [
                QuickActionItem(
                  label: 'Nuevo entreno',
                  subtitle: 'Registrar sesión',
                  icon: Icons.fitness_center_rounded,
                  onTap: () => context.push('/app/entrenamientos'),
                ),
                QuickActionItem(
                  label: 'Registrar comida',
                  subtitle: 'Calorías y macros',
                  icon: Icons.restaurant_rounded,
                  onTap: () => context.push('/app/comidas'),
                ),
                QuickActionItem(
                  label: 'Foto progreso',
                  subtitle: 'Guardar avance',
                  icon: Icons.photo_camera_outlined,
                  onTap: () => context.push('/app/foto'),
                ),
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
