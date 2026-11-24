import 'package:flutter/material.dart';

import '../../../../design_system/components/primary_button.dart';
import '../../../../design_system/tokens/app_colors.dart';

/// CTA principal de auth con indicador de carga mientras se envía.
///
/// Envuelve [PrimaryButton] sin modificarlo: durante el envío cambia la
/// etiqueta, deshabilita el toque y superpone un spinner. Migrar a
/// `PrimaryButton(isLoading:)` del DS en #222.
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final action = isLoading ? null : onPressed;
    return Semantics(
      button: true,
      enabled: action != null,
      label: isLoading ? loadingLabel : label,
      onTap: action,
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PrimaryButton(
            label: isLoading ? loadingLabel : label,
            onPressed: action,
          ),
          if (isLoading)
            const Positioned(
              left: 24,
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
