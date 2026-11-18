import '../domain/macros.dart';

/// Hasta una décima, sin ceros sobrantes.
String formatAmount(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

String formatMacros(Macros macros) =>
    '${formatAmount(macros.kcal)} kcal · P ${formatAmount(macros.proteinG)} g'
    ' · C ${formatAmount(macros.carbsG)} g · G ${formatAmount(macros.fatG)} g';
