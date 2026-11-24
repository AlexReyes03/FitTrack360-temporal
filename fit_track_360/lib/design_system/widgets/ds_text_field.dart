import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';

/// Campo de texto del DS: label secundario w600, fondo oscuro translucido,
/// borde blanco al 18% y foco con borde al 60% mas halo suave.
///
/// Si [obscureText] es true muestra un boton para alternar la visibilidad del
/// texto y, cuando [errorText] no es null, pinta el borde y el mensaje en el
/// color de error del DS.
///
/// Accesibilidad: la etiqueta visible se excluye del arbol semantico y se
/// expone una sola vez como label del campo, asi el lector de pantalla anuncia
/// "Correo, campo de texto" sin repetirla. Para formularios usa
/// [textInputAction] + [onSubmitted] (avanzar con "Siguiente", enviar con
/// "Listo") y [autofillHints] dentro de un `AutofillGroup`.
///
/// Para valores numericos usa [DsTextField.integer] o [DsTextField.decimal]:
/// impiden letras desde el teclado y permiten mostrar [errorText] por campo.
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

  /// Accion del boton de envio del teclado (`next`, `done`, `search`...).
  final TextInputAction? textInputAction;

  /// Se llama al pulsar la accion del teclado.
  final ValueChanged<String>? onSubmitted;

  /// Pistas para el gestor de contrasenas / autocompletado del sistema.
  final Iterable<String>? autofillHints;

  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  /// Limite de caracteres; muestra el contador del campo cuando no es null.
  final int? maxLength;

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
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
  });

  /// Campo para enteros no negativos (series, repeticiones, pasos...).
  /// Solo acepta digitos.
  DsTextField.integer({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    this.maxLength,
  }) : obscureText = false,
       keyboardType = TextInputType.number,
       autofillHints = null,
       textCapitalization = TextCapitalization.none,
       inputFormatters = [FilteringTextInputFormatter.digitsOnly];

  /// Campo para decimales no negativos (peso, kcal, macros...). Acepta coma
  /// o punto como separador (uno solo) y, si se indica, como maximo
  /// [maxDecimals] decimales. Convierte el texto con [parseDecimal].
  DsTextField.decimal({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    this.maxLength,
    int? maxDecimals,
  }) : obscureText = false,
       keyboardType = const TextInputType.numberWithOptions(decimal: true),
       autofillHints = null,
       textCapitalization = TextCapitalization.none,
       inputFormatters = [
         FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
         _DecimalTextInputFormatter(maxDecimals: maxDecimals),
       ];

  /// Convierte el texto de un campo decimal aceptando coma o punto.
  /// Devuelve null si esta vacio o no es un numero.
  static double? parseDecimal(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

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
        // La etiqueta visual no se anuncia por separado: el lector la recibe
        // una sola vez como label del campo (Semantics de abajo).
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: widget.label,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            enabled: widget.enabled,
            autocorrect: !widget.obscureText,
            enableSuggestions: !widget.obscureText,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            textCapitalization: widget.textCapitalization,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.5,
            ),
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
        ),
      ],
    );
  }
}

/// Garantiza un solo separador decimal (coma o punto) y, opcionalmente, un
/// maximo de decimales. Si la edicion no cumple, conserva el valor previo.
class _DecimalTextInputFormatter extends TextInputFormatter {
  _DecimalTextInputFormatter({this.maxDecimals});

  final int? maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final decimals = maxDecimals;
    final pattern = decimals == null
        ? RegExp(r'^\d*[.,]?\d*$')
        : RegExp('^\\d*([.,]\\d{0,$decimals})?\$');
    return pattern.hasMatch(text) ? newValue : oldValue;
  }
}
