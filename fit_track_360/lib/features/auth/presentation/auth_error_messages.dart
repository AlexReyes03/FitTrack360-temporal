import 'dart:async';

import 'package:http/http.dart' as http;

import '../data/auth_api.dart';
import '../data/google_auth_gateway.dart';
import '../domain/auth_messages.dart';

/// Traduce cualquier error de autenticación a un mensaje en español listo
/// para la UI. Nunca devuelve el texto técnico del error.
///
/// - Respuestas del backend ([AuthApiException] con `statusCode`): se decide
///   por status/clasificación; el `message` de Nest («Token invalido»,
///   «Internal server error», errores de class-validator) no se muestra.
/// - [AuthApiException] sin `statusCode`: el mensaje lo redactó el cliente
///   (Firebase ya traducido por [AuthMessages.forFirebaseCode] o reglas del
///   flujo de Google), así que se conserva.
/// - Fallos de Google con copy controlado ([GoogleSignInFailure]).
/// - Errores de red o tiempo de espera: [AuthMessages.network].
/// - Cualquier otro: el genérico del [flow].
String describeAuthError(Object error, AuthFlow flow) {
  if (error is AuthApiException) {
    if (error.statusCode == null) return error.message;
    return _describeApiFailure(error, flow);
  }
  if (error is GoogleSignInFailure) return error.message;
  if (error is http.ClientException || error is TimeoutException) {
    return AuthMessages.network;
  }
  return AuthMessages.genericFor(flow);
}

String _describeApiFailure(AuthApiException error, AuthFlow flow) {
  switch (classifyAuthApiFailure(error)) {
    case AuthApiFailure.notSynced:
      return AuthMessages.accountNotSynced;
    case AuthApiFailure.invalidSession:
      return AuthMessages.sessionInvalid;
    case AuthApiFailure.emailTaken:
      return AuthMessages.emailAlreadyRegistered;
    case AuthApiFailure.usernameTaken:
      return AuthMessages.usernameAlreadyRegistered;
    case AuthApiFailure.firebaseAccountTaken:
      return AuthMessages.accountAlreadyRegistered;
    case AuthApiFailure.other:
      if (error.statusCode == 429) return AuthMessages.tooManyRequests;
      return AuthMessages.genericFor(flow);
  }
}
