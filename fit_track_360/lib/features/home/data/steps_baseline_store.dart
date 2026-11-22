import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Primera lectura acumulada del podómetro en un día local.
class StepsBaseline {
  const StepsBaseline({
    required this.day,
    required this.steps,
    required this.capturedAt,
  });

  /// Día local `AAAA-MM-DD`.
  final String day;

  /// Pasos acumulados desde el último reinicio al momento de la captura.
  final int steps;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
    'day': day,
    'steps': steps,
    'capturedAt': capturedAt.toIso8601String(),
  };

  static StepsBaseline? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return StepsBaseline(
        day: json['day'] as String,
        steps: (json['steps'] as num).toInt(),
        capturedAt: DateTime.parse(json['capturedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Persistencia local de la línea base de pasos (O5). No sale del teléfono.
abstract class StepsBaselineStore {
  Future<StepsBaseline?> readBaseline();

  Future<void> writeBaseline(StepsBaseline baseline);

  /// Solo iOS: recuerda que Motion ya entregó lecturas, para no volver a
  /// pedir la acción «Mostrar mis pasos» en cada apertura.
  Future<bool> readMotionAuthorized();

  Future<void> writeMotionAuthorized(bool value);
}

/// Implementación sobre `flutter_secure_storage`, que ya es dependencia
/// de la app; evita agregar un paquete solo para dos valores.
class SecureStepsBaselineStore implements StepsBaselineStore {
  SecureStepsBaselineStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _baselineKey = 'steps_daily_baseline';
  static const _motionKey = 'steps_motion_authorized';

  final FlutterSecureStorage _storage;

  @override
  Future<StepsBaseline?> readBaseline() async =>
      StepsBaseline.tryParse(await _storage.read(key: _baselineKey));

  @override
  Future<void> writeBaseline(StepsBaseline baseline) =>
      _storage.write(key: _baselineKey, value: jsonEncode(baseline.toJson()));

  @override
  Future<bool> readMotionAuthorized() async =>
      await _storage.read(key: _motionKey) == 'true';

  @override
  Future<void> writeMotionAuthorized(bool value) => value
      ? _storage.write(key: _motionKey, value: 'true')
      : _storage.delete(key: _motionKey);
}
