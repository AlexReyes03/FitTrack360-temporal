import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session_storage.dart';
import '../../../design_system/components/app_logo.dart';
import '../../../design_system/templates/app_scaffold_template.dart';

/// Splash Liquid Glass mientras se resuelve la sesión: con ID token va a
/// `/app`; sin sesión va directo a `/login` (sin espera fija ni botón).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    String? accessToken;
    try {
      accessToken = await appSessionStorage.readAccessToken();
    } catch (_) {
      accessToken = null;
    }
    if (!mounted) return;
    context.go(accessToken == null ? '/login' : '/app');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: Center(
        child: Semantics(
          label: 'FitTrack360, cargando',
          child: const AppLogo(
            variant: AppLogoVariant.full,
            height: AppLogo.splashHeight,
          ),
        ),
      ),
    );
  }
}
