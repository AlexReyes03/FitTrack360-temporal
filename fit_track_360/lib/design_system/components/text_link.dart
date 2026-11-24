import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// Enlace de texto con área táctil de 48 dp (terciario: navegación o acción
/// de bajo peso, p. ej. «¿Olvidaste tu contraseña?», «Captura manual»).
///
/// - Por defecto: `textPrimary`, peso 700 y subrayado en `textSecondary`.
/// - [subtle]: `textSecondary` sin subrayado, para acciones auxiliares
///   junto a un formulario.
class TextLink extends StatelessWidget {
  const TextLink({
    super.key,
    required this.label,
    this.onPressed,
    this.subtle = false,
  });

  final String label;

  /// `null` deshabilita el enlace (`textMuted`).
  final VoidCallback? onPressed;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? AppColors.textMuted
        : subtle
        ? AppColors.textSecondary
        : AppColors.textPrimary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        label,
        style: AppTypography.body.copyWith(
          color: color,
          fontWeight: subtle ? FontWeight.w600 : FontWeight.w700,
          decoration: subtle ? TextDecoration.none : TextDecoration.underline,
          decorationColor: AppColors.textSecondary,
        ),
      ),
    );
  }
}
