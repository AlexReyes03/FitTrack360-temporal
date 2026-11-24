import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_typography.dart';

/// Enlace de texto de auth con área táctil de 48dp (TextButton).
class AuthTextLink extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AuthTextLink({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        label,
        style: AppTypography.body.copyWith(
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Pregunta + enlace centrados, p. ej. «¿Ya tienes una cuenta? Inicia sesión».
class AuthLinkRow extends StatelessWidget {
  final String prompt;
  final String label;
  final VoidCallback? onPressed;

  const AuthLinkRow({
    super.key,
    required this.prompt,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        AuthTextLink(label: label, onPressed: onPressed),
      ],
    );
  }
}
