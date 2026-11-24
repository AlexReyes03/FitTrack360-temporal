import 'dart:async';

import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/auth/data/google_auth_gateway.dart';
import 'package:fit_track_360/features/auth/domain/auth_messages.dart';
import 'package:fit_track_360/features/auth/presentation/auth_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('describeAuthError: respuestas del backend', () {
    test('401 «Token invalido» no se muestra crudo', () {
      final message = describeAuthError(
        const AuthApiException('Token invalido', statusCode: 401),
        AuthFlow.login,
      );
      expect(message, AuthMessages.sessionInvalid);
      expect(message, isNot(contains('Token invalido')));
    });

    test('401 no sincronizado pide crear cuenta', () {
      expect(
        describeAuthError(
          const AuthApiException('Usuario no sincronizado', statusCode: 401),
          AuthFlow.login,
        ),
        AuthMessages.accountNotSynced,
      );
    });

    test('409 por correo y por usuario usan el copy de registro', () {
      expect(
        describeAuthError(
          const AuthApiException(
            'El correo ya esta registrado',
            statusCode: 409,
          ),
          AuthFlow.register,
        ),
        AuthMessages.emailAlreadyRegistered,
      );
      expect(
        describeAuthError(
          const AuthApiException(
            'El usuario ya esta registrado',
            statusCode: 409,
          ),
          AuthFlow.register,
        ),
        AuthMessages.usernameAlreadyRegistered,
      );
      expect(
        describeAuthError(
          const AuthApiException(
            'La cuenta Firebase ya esta registrada',
            statusCode: 409,
          ),
          AuthFlow.register,
        ),
        AuthMessages.accountAlreadyRegistered,
      );
    });

    test('500 «Internal server error» cae en el genérico del flujo', () {
      const error = AuthApiException('Internal server error', statusCode: 500);
      expect(
        describeAuthError(error, AuthFlow.login),
        AuthMessages.loginGeneric,
      );
      expect(
        describeAuthError(error, AuthFlow.register),
        AuthMessages.registerGeneric,
      );
      expect(
        describeAuthError(error, AuthFlow.recovery),
        AuthMessages.recoveryGeneric,
      );
    });

    test('400 de validación en inglés no se muestra crudo', () {
      final message = describeAuthError(
        const AuthApiException(
          'username must match /^[a-zA-Z0-9_]+\$/ regular expression',
          statusCode: 400,
        ),
        AuthFlow.register,
      );
      expect(message, AuthMessages.registerGeneric);
    });

    test('429 indica demasiados intentos', () {
      expect(
        describeAuthError(
          const AuthApiException('ThrottlerException', statusCode: 429),
          AuthFlow.login,
        ),
        AuthMessages.tooManyRequests,
      );
    });
  });

  group('describeAuthError: errores locales', () {
    test('mensaje propio del cliente (sin status) se conserva', () {
      expect(
        describeAuthError(
          const AuthApiException(AuthMessages.invalidCredentials),
          AuthFlow.login,
        ),
        AuthMessages.invalidCredentials,
      );
    });

    test('fallo de Google con copy controlado se conserva', () {
      expect(
        describeAuthError(
          const GoogleSignInNetworkException(),
          AuthFlow.register,
        ),
        googleSignInNetworkMessage,
      );
    });

    test('errores de red sin respuesta muestran el copy de conexión', () {
      expect(
        describeAuthError(
          http.ClientException('SocketException: Failed host lookup'),
          AuthFlow.login,
        ),
        AuthMessages.network,
      );
      expect(
        describeAuthError(TimeoutException('x'), AuthFlow.recovery),
        AuthMessages.network,
      );
    });

    test('cualquier otra excepción usa el genérico, nunca su texto', () {
      final message = describeAuthError(
        StateError('Bad state: boom'),
        AuthFlow.register,
      );
      expect(message, AuthMessages.registerGeneric);
    });
  });

  group('AuthMessages.forFirebaseCode', () {
    test('credenciales inválidas no indican qué campo falló', () {
      for (final code in [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
        'INVALID_LOGIN_CREDENTIALS',
      ]) {
        expect(
          AuthMessages.forFirebaseCode(code),
          AuthMessages.invalidCredentials,
          reason: code,
        );
      }
    });

    test('códigos conocidos tienen copy con acentos', () {
      expect(
        AuthMessages.forFirebaseCode('email-already-in-use'),
        AuthMessages.emailAlreadyRegistered,
      );
      expect(
        AuthMessages.forFirebaseCode('too-many-requests'),
        AuthMessages.tooManyRequests,
      );
      expect(
        AuthMessages.forFirebaseCode('network-request-failed'),
        AuthMessages.network,
      );
      expect(
        AuthMessages.forFirebaseCode('user-disabled'),
        'Esta cuenta está deshabilitada.',
      );
    });

    test('código desconocido no expone el mensaje técnico', () {
      expect(
        AuthMessages.forFirebaseCode('internal-error'),
        AuthMessages.authGeneric,
      );
    });
  });
}
