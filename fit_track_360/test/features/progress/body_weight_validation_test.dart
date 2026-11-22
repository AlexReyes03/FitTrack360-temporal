import 'package:fit_track_360/features/progress/domain/body_weight_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta punto o coma decimal', () {
    expect(validateBodyWeightKg('74.2').weightKg, 74.2);
    expect(validateBodyWeightKg(' 73,8 ').weightKg, 73.8);
    expect(validateBodyWeightKg('74.2').error, isNull);
  });

  test('vacío pide capturar el peso', () {
    final result = validateBodyWeightKg('   ');
    expect(result.weightKg, isNull);
    expect(result.error, 'Ingresa tu peso en kg para guardar el check-in.');
  });

  test('rechaza texto, cero, negativos, no finitos y fuera de rango', () {
    for (final input in [
      'abc',
      '0',
      '-70',
      'NaN',
      'Infinity',
      '1e400',
      '19.9',
      '500.1',
      '74..2',
      '7,4,2',
    ]) {
      final result = validateBodyWeightKg(input);
      expect(result.weightKg, isNull, reason: input);
      expect(
        result.error,
        'Ingresa un peso válido entre 20 y 500 kg.',
        reason: input,
      );
    }
  });

  test('los límites 20 y 500 son válidos', () {
    expect(validateBodyWeightKg('20').weightKg, 20);
    expect(validateBodyWeightKg('500').weightKg, 500);
    expect(BodyWeightLimits.minKg, 20);
    expect(BodyWeightLimits.maxKg, 500);
  });
}
