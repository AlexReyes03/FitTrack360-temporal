import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Campo de texto del DS: label secundario w600, fondo oscuro translucido,
/// borde blanco al 18% y foco con borde al 60% mas halo suave.
///
/// Si [obscureText] es true muestra un boton para alternar la visibilidad del
/// texto y, cuando [errorText] no es null, pinta el borde y el mensaje en el
/// color de error del DS.
class DsTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final String? errorText;

  const DsTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.errorText,
  });

  @override
  State<DsTextField> createState() => _DsTextFieldState();
}

class _DsTextFieldState extends State<DsTextField> {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant DsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscureText != oldWidget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          autocorrect: !widget.obscureText,
          enableSuggestions: !widget.obscureText,
          onChanged: widget.onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15.5),
          cursorColor: AppColors.accentWhite,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            errorText: widget.errorText,
            errorStyle: const TextStyle(
              color: AppColors.dangerText,
              fontSize: 12.5,
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    color: AppColors.textMuted,
                    tooltip: _obscured
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                  )
                : null,
            filled: true,
            fillColor: const Color(0xB807080C),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.dangerBorder),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.dangerBorder,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
