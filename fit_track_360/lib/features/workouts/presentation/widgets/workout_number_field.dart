import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_typography.dart';
import 'tracker_controls.dart';

/// Filtros de captura numérica del feature de entrenamientos.
///
/// `DsTextField` aún no acepta `inputFormatters`; por eso estos campos viven
/// en el feature con el mismo estilo glass. Migrar a DS en #222.
abstract final class WorkoutInputFormatters {
  /// Solo dígitos (repeticiones, descanso, duración).
  static final List<TextInputFormatter> integer = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];

  /// Dígitos con un separador decimal (`.` o `,`) y hasta dos decimales.
  static final List<TextInputFormatter> decimal = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}([.,]\d{0,2})?')),
  ];
}

/// Campo numérico con stepper −/+ del tracker y del editor de series.
///
/// Muestra [errorText] bajo el campo y pinta el borde en rojo; así cada campo
/// indica su propio error en lugar de un mensaje global.
class WorkoutStepperField extends StatelessWidget {
  const WorkoutStepperField({
    super.key,
    required this.label,
    required this.controller,
    required this.decrementTooltip,
    required this.incrementTooltip,
    required this.inputFormatters,
    this.keyboardType = TextInputType.number,
    this.hasError = false,
    this.errorText,
    this.fieldKey,
    this.onChanged,
    this.onDecrement,
    this.onIncrement,
  });

  final String label;
  final TextEditingController controller;
  final String decrementTooltip;
  final String incrementTooltip;
  final List<TextInputFormatter> inputFormatters;
  final TextInputType keyboardType;
  final bool hasError;
  final String? errorText;

  /// Llave del `TextField` interno, útil para pruebas.
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final showError = hasError || errorText != null;
    final borderColor = showError
        ? AppColors.dangerBorder
        : Colors.white.withValues(alpha: 0.18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: showError ? AppColors.dangerText : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TrackerIconControl(
              icon: Icons.remove_rounded,
              tooltip: decrementTooltip,
              size: 34,
              onPressed: onDecrement,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                key: fieldKey,
                controller: controller,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                textAlign: TextAlign.center,
                onChanged: onChanged,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                cursorColor: AppColors.accentWhite,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xB807080C),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 8,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.badge + 2),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.badge + 2),
                    borderSide: BorderSide(
                      color: showError
                          ? AppColors.dangerBorder
                          : Colors.white.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            TrackerIconControl(
              icon: Icons.add_rounded,
              tooltip: incrementTooltip,
              size: 34,
              onPressed: onIncrement,
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTypography.body.copyWith(
              fontSize: 12,
              height: 1.3,
              color: AppColors.dangerText,
            ),
          ),
        ],
      ],
    );
  }
}

/// Campo numérico glass con etiqueta, ayuda y error propio (mismo estilo que
/// `DsTextField`, más `inputFormatters`). Migrar a DS en #222.
class WorkoutNumberField extends StatelessWidget {
  const WorkoutNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.inputFormatters,
    this.keyboardType = TextInputType.number,
    this.helperText,
    this.errorText,
    this.suffixText,
    this.enabled = true,
    this.fieldKey,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final List<TextInputFormatter> inputFormatters;
  final TextInputType keyboardType;
  final String? helperText;
  final String? errorText;
  final String? suffixText;
  final bool enabled;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          enabled: enabled,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15.5),
          cursorColor: AppColors.accentWhite,
          decoration: InputDecoration(
            helperText: errorText == null ? helperText : null,
            helperMaxLines: 2,
            helperStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
            ),
            errorText: errorText,
            errorMaxLines: 2,
            errorStyle: const TextStyle(
              color: AppColors.dangerText,
              fontSize: 12.5,
            ),
            suffixText: suffixText,
            suffixStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: const Color(0xB807080C),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            enabledBorder: _border(Colors.white.withValues(alpha: 0.18)),
            focusedBorder: _border(
              Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            disabledBorder: _border(Colors.white.withValues(alpha: 0.10)),
            errorBorder: _border(AppColors.dangerBorder),
            focusedErrorBorder: _border(AppColors.dangerBorder, width: 1.5),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: BorderSide(color: color, width: width),
      );
}
