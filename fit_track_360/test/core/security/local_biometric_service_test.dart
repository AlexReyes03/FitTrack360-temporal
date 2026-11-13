// Spec O1 (docs/permisos.md, issue #131) -> pruebas:
// - O1-1 isAvailable es true solo si el equipo puede revisar biometría y hay
//   al menos una registrada; ante un error devuelve false.
// - O1-2 authenticate pide solo biometría (biometricOnly) con el motivo dado.
// - O1-3 authenticate nunca lanza: ante un error devuelve false.
// - O1-4 La app solo recibe éxito o fallo (bool); no maneja datos biométricos.
import 'package:fit_track_360/core/security/local_biometric_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthPlugin implements AuthPlugin {
  bool canCheck = true;
  bool enrolled = true;
  bool result = true;
  Object? error;
  String? lastReason;
  bool? lastBiometricOnly;

  @override
  Future<bool> canCheckBiometrics() async {
    if (error != null) throw error!;
    return canCheck;
  }

  @override
  Future<bool> hasEnrolledBiometrics() async {
    if (error != null) throw error!;
    return enrolled;
  }

  @override
  Future<bool> authenticate({
    required String reason,
    required bool biometricOnly,
  }) async {
    lastReason = reason;
    lastBiometricOnly = biometricOnly;
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  late FakeAuthPlugin plugin;
  late LocalBiometricService service;

  setUp(() {
    plugin = FakeAuthPlugin();
    service = LocalBiometricService(plugin: plugin);
  });

  group('O1-1 isAvailable', () {
    test('true si puede revisar biometría y hay una registrada', () async {
      expect(await service.isAvailable(), isTrue);
    });

    test('false si el equipo no admite biometría', () async {
      plugin.canCheck = false;
      expect(await service.isAvailable(), isFalse);
    });

    test('false si no hay biometría registrada', () async {
      plugin.enrolled = false;
      expect(await service.isAvailable(), isFalse);
    });

    test('false ante un error del sistema', () async {
      plugin.error = PlatformException(code: 'NotAvailable');
      expect(await service.isAvailable(), isFalse);
    });

    test('false si falta el plugin (web)', () async {
      plugin.error = MissingPluginException();
      expect(await service.isAvailable(), isFalse);
    });
  });

  group('O1-2 authenticate', () {
    test('usa biometricOnly y el motivo dado', () async {
      final ok = await service.authenticate(reason: 'Confirma tu identidad');
      expect(ok, isTrue);
      expect(plugin.lastBiometricOnly, isTrue);
      expect(plugin.lastReason, 'Confirma tu identidad');
    });

    test('devuelve false si el usuario cancela o falla', () async {
      plugin.result = false;
      expect(await service.authenticate(reason: 'Confirma'), isFalse);
    });
  });

  group('O1-3 authenticate nunca lanza', () {
    for (final error in <Object>[
      PlatformException(code: 'LockedOut'),
      MissingPluginException(),
      StateError('inesperado'),
    ]) {
      test('devuelve false ante ${error.runtimeType}', () async {
        plugin.error = error;
        expect(await service.authenticate(reason: 'Confirma'), isFalse);
      });
    }
  });
}
