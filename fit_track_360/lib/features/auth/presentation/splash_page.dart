import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session_storage.dart';
import '../../../design_system/components/app_logo.dart';
import '../../../design_system/components/primary_button.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';

/// Placeholder Liquid Glass. Si hay access token va a /app; si no, permanece
/// aqui. "Ir a Login" es un atajo temporal, sin logica de auth.
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
    await Future.delayed(const Duration(milliseconds: 700));
    final accessToken = await SessionStorage().readAccessToken();
    if (!mounted || accessToken == null) return;
    context.go('/app');
  }

  void _goToLogin() => context.go('/login');

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(
              variant: AppLogoVariant.full,
              height: AppLogo.splashHeight,
            ),
            const SizedBox(height: 16),
            Text(
              'Tu progreso, en un solo lugar',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              child: PrimaryButton(label: 'Ir a Login', onPressed: _goToLogin),
            ),
          ],
        ),
      ),
    );
  }
}
