import 'package:fit_track_360/features/auth/domain/auth_messages.dart';
import 'package:fit_track_360/features/auth/domain/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

RegisterForm _form({
  String displayName = 'Ana',
  String username = 'ana_01',
  String email = 'ana@test.com',
  String password = 'Password1',
  String? confirmPassword,
}) => RegisterForm(
  displayName: displayName,
  username: username,
  email: email,
  password: password,
  confirmPassword: confirmPassword ?? password,
);

void main() {
  group('validateLogin', () {
    test('campos vacíos piden completarlos', () {
      expect(
        AuthValidators.validateLogin(email: '', password: 'x'),
        AuthMessages.requiredFields,
      );
    });

    test('correo con formato inválido', () {
      expect(
        AuthValidators.validateLogin(email: 'ana', password: 'x'),
        AuthMessages.invalidEmail,
      );
    });
  });

  group('validateRegistration', () {
    test('formulario válido con consentimiento', () {
      expect(
        AuthValidators.validateRegistration(_form(), privacyConsent: true),
        isNull,
      );
    });

    test('campos vacíos se reportan antes que el consentimiento', () {
      final form = _form(displayName: '  ', password: '');
      expect(form.missingFields, {
        RegisterField.displayName,
        RegisterField.password,
        RegisterField.confirmPassword,
      });
      expect(
        AuthValidators.validateRegistration(form, privacyConsent: false),
        AuthMessages.requiredFields,
      );
    });

    test('sin consentimiento explica por qué no avanza', () {
      expect(
        AuthValidators.validateRegistration(_form(), privacyConsent: false),
        AuthMessages.consentRequired,
      );
    });

    test('las contraseñas no se recortan (igual que en login)', () {
      // Con recorte, "Password1 " y "Password1" coincidirían.
      expect(
        AuthValidators.validateRegistration(
          _form(password: 'Password1 ', confirmPassword: 'Password1'),
          privacyConsent: true,
        ),
        AuthMessages.passwordMismatch,
      );
      // Una contraseña de 8 caracteres con espacios es válida tal cual.
      expect(
        AuthValidators.validateRegistration(
          _form(password: ' abc def '),
          privacyConsent: true,
        ),
        isNull,
      );
    });

    test('usuario inválido y contraseña corta', () {
      expect(
        AuthValidators.validateRegistration(
          _form(username: 'a-b'),
          privacyConsent: true,
        ),
        AuthMessages.invalidUsername,
      );
      expect(
        AuthValidators.validateRegistration(
          _form(password: 'short'),
          privacyConsent: true,
        ),
        AuthMessages.passwordTooShort,
      );
    });
  });
}
