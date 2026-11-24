import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../state/progress_view_state.dart';

/// Aviso de resultado con tono visible (éxito, aviso o error) y anuncio para
/// lectores de pantalla. Privado de Progreso: migrar a `StatusBanner` del DS
/// en #222.
class ProgressStatusBanner extends StatelessWidget {
  const ProgressStatusBanner({
    super.key,
    required this.message,
    required this.tone,
    this.title,
  });

  final String message;
  final ProgressFeedbackTone tone;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final (fill, border, text, icon) = switch (tone) {
      ProgressFeedbackTone.success => (
        AppColors.glassFillStrong,
        AppColors.glassBorderStrong,
        AppColors.textPrimary,
        Icons.check_circle_outline_rounded,
      ),
      ProgressFeedbackTone.warning => (
        AppColors.warningFill,
        AppColors.warningBorder,
        AppColors.warningText,
        Icons.info_outline_rounded,
      ),
      ProgressFeedbackTone.error => (
        AppColors.dangerFill,
        AppColors.dangerBorder,
        AppColors.dangerText,
        Icons.error_outline_rounded,
      ),
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: Key('progress-feedback-${tone.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadii.banner),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: text, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: TextStyle(
                        color: text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: TextStyle(color: text, fontSize: 13.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
