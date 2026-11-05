import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/session_storage.dart';
import '../../../design_system/templates/app_scaffold_template.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../design_system/widgets/primary_button.dart';


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
            const _BrandPill(),
            const SizedBox(height: 28),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.45, 1.0],
                colors: [
                  AppColors.accentWhite,
                  AppColors.zinc100,
                  AppColors.gray400,
                ],
              ).createShader(bounds),
              child: Text(
                'FitTrack360',
                style: AppTypography.pageTitle.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu progreso, en un solo lugar',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              child: PrimaryButton(
                label: 'Ir a Login',
                onPressed: _goToLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: 8),
          const Text(
            'FITTRACK360',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
