import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_typography.dart';

/// Tono del [AuthStatusBanner].
enum AuthStatusTone { danger, info }

/// Banner de estado de auth (error o confirmación) que va justo debajo del
/// CTA. Es una live region: los lectores de pantalla anuncian su texto en
/// cuanto aparece o cambia.
///
/// Privado de la feature; migrar a un `StatusBanner` del DS en #222.
class AuthStatusBanner extends StatelessWidget {
  final String message;
  final AuthStatusTone tone;

  const AuthStatusBanner({
    super.key,
    required this.message,
    this.tone = AuthStatusTone.danger,
  });

  @override
  Widget build(BuildContext context) {
    final danger = tone == AuthStatusTone.danger;
    final textColor = danger ? AppColors.dangerText : AppColors.zinc100;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: danger ? AppColors.dangerFill : AppColors.glassFillStrong,
          borderRadius: BorderRadius.circular(AppRadii.banner),
          border: Border.all(
            color: danger
                ? AppColors.dangerBorder
                : AppColors.glassBorderStrong,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                danger ? Icons.error_outline : Icons.check_circle_outline,
                size: 20,
                color: textColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lleva el banner identificado por [key] a la vista tras el próximo frame,
/// para que el error nunca quede escondido bajo el contenido (p. ej. la
/// sección de Google en registro).
void revealAuthBanner(GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = key.currentContext;
    if (context == null || !context.mounted) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  });
}
