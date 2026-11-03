import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session_storage.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/widgets/app_background.dart';
import '../../../design_system/widgets/glass_surface.dart';
import '../../../design_system/widgets/primary_button.dart';
import '../../auth/data/auth_api.dart';

/// Shell post-login. Carga el perfil con el cliente HTTP y cierra sesion
/// revocando el refresh en el API, limpiando storage local y volviendo a login.
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  final ApiClient _api = ApiClient();
  final SessionStorage _storage = SessionStorage();

  String? _displayName;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.me();
      if (!mounted) return;
      setState(() => _displayName = profile.displayName);
    } on SessionExpiredException {
      if (!mounted) return;
      context.go('/login');
    } catch (_) {
      // Sin red o perfil no disponible: se mantiene el saludo generico.
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
                    padding: const EdgeInsets.all(24),
                    child: PrimaryButton(
                      label: _loggingOut ? 'Cerrando...' : 'Cerrar sesion',
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
