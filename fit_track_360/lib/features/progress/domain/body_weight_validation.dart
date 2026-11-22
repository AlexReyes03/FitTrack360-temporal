/// Límites del peso del check-in. El DTO de métricas del API (#179) solo exige
/// un número finito y positivo; el rango 20–500 kg evita capturas absurdas.
class BodyWeightLimits {
  BodyWeightLimits._();

  static const double minKg = 20;
  static const double maxKg = 500;
}

/// Resultado de validar el peso capturado: valor limpio o mensaje de error.
class BodyWeightValidation {
  const BodyWeightValidation._({this.weightKg, this.error});

  final double? weightKg;
  final String? error;

  bool get isValid => weightKg != null;
}

const String kBodyWeightRequiredError =
    'Ingresa tu peso en kg para guardar el check-in.';
const String kBodyWeightInvalidError =
    'Ingresa un peso válido entre 20 y 500 kg.';

final RegExp _decimal = RegExp(r'^\d+([.,]\d+)?$');

/// Acepta punto o coma decimal (`74.2` / `74,2`).
BodyWeightValidation validateBodyWeightKg(String input) {
  final text = input.trim();
  if (text.isEmpty) {
    return const BodyWeightValidation._(error: kBodyWeightRequiredError);
  }
  if (!_decimal.hasMatch(text)) {
    return const BodyWeightValidation._(error: kBodyWeightInvalidError);
  }
  final value = double.tryParse(text.replaceAll(',', '.'));
  if (value == null ||
      !value.isFinite ||
      value < BodyWeightLimits.minKg ||
      value > BodyWeightLimits.maxKg) {
    return const BodyWeightValidation._(error: kBodyWeightInvalidError);
  }
  return BodyWeightValidation._(weightKg: value);
}
