import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';

AuthApiFailure _classify(int? status, String message) =>
    classifyAuthApiFailure(AuthApiException(message, statusCode: status));

void main() {
  group('classifyAuthApiFailure', () {
    test('401 Usuario no sincronizado -> notSynced', () {
      expect(
        _classify(401, 'Usuario no sincronizado'),
        AuthApiFailure.notSynced,
      );
    });

    test('401 Token invalido -> invalidSession (no dispara registro)', () {
      expect(_classify(401, 'Token invalido'), AuthApiFailure.invalidSession);
    });

    test('409 de session (correo con otra cuenta) -> emailTaken', () {
      expect(
        _classify(409, 'El correo ya esta registrado con otra cuenta'),
        AuthApiFailure.emailTaken,
      );
    });

    test('409 de register por correo -> emailTaken', () {
      expect(
        _classify(409, 'El correo ya esta registrado'),
        AuthApiFailure.emailTaken,
      );
    });

    test('409 de register por username -> usernameTaken', () {
      expect(
        _classify(409, 'El usuario ya esta registrado'),
        AuthApiFailure.usernameTaken,
      );
    });

    test('409 de register por UID Firebase -> firebaseAccountTaken', () {
      expect(
        _classify(409, 'La cuenta Firebase ya esta registrada'),
        AuthApiFailure.firebaseAccountTaken,
      );
    });

    test('el texto sin status no decide el flujo', () {
      expect(_classify(null, 'Usuario no sincronizado'), AuthApiFailure.other);
      expect(
        _classify(400, 'El usuario ya esta registrado'),
        AuthApiFailure.other,
      );
    });

    test('otros status -> other', () {
      expect(_classify(500, 'Internal'), AuthApiFailure.other);
    });
  });
}
