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
import '../../../design_system/widgets/app_background.dart';
import '../../auth/data/auth_api.dart';

/// Shell post-login. Carga el perfil con el cliente HTTP y cierra sesion
/// revocando el refresh en el API, limpiando storage local y volviendo a login.
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
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final SessionStorage _storage =
      widget.sessionStorage ?? SessionStorage();
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
    // Dos cargas simultaneas con el access vencido harian dos refresh; el
    // segundo usaria un token ya revocado y cerraria la sesion.
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
    final refreshToken = await _storage.readRefreshToken();
    try {
      if (refreshToken != null) {
        await logout(refreshToken: refreshToken);
      }
    } catch (_) {
      // Si el API falla, la sesion local se limpia igual.
    } finally {
      await _storage.clear();
    }
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
                  OfflineBanner(service: _connectivity, onRetry: _loadProfile),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: _Header(onProfileTap: () {}),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: GlassSurface(
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
                            const SizedBox(height: 24),
                            Container(
                              height: 160,
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
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
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
                          onPressed: () => context.push('/app/comidas'),
                          child: const Text(
                            'Comidas',
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
