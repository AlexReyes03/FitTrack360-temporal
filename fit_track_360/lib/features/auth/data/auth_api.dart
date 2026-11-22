import 'dart:convert';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Perfil sincronizado por Nest tras register/session (sin tokens propios).
class AuthUser {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String firebaseUid;

  const AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.firebaseUid,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      firebaseUid: json['firebaseUid'] as String,
    );
  }
}

/// Perfil del usuario autenticado (GET /users/me).
class UserProfile {
  final String id;
  final String email;
  final String username;
  final String displayName;

  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
    );
  }
}

String apiErrorMessage(http.Response response) {
  try {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final message = body is Map<String, dynamic> ? body['message'] : null;
    if (message is List) return message.join(' ');
    if (message is String) return message;
  } catch (_) {
    // Sin JSON util.
  }
  return 'No se pudo conectar';
}

Map<String, dynamic> _decodeBody(http.Response response) =>
    jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

Map<String, String> _bearerHeaders(String idToken) => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer $idToken',
};

/// Crea el User en PostgreSQL tras el registro en Firebase Auth.
Future<AuthUser> syncRegister({
  required String idToken,
  required String username,
  required String displayName,
  required bool privacyConsent,
  required String privacyNoticeVersion,
}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/register'),
    headers: _bearerHeaders(idToken),
    body: jsonEncode({
      'username': username,
      'displayName': displayName,
      'privacyConsent': privacyConsent,
      'privacyNoticeVersion': privacyNoticeVersion,
    }),
  );
  if (response.statusCode != 201) {
    throw AuthApiException(
      apiErrorMessage(response),
      statusCode: response.statusCode,
    );
  }
  return AuthUser.fromJson(_decodeBody(response));
}

/// Resuelve el User existente tras login Firebase.
Future<AuthUser> syncSession({required String idToken}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/session'),
    headers: _bearerHeaders(idToken),
  );
  if (response.statusCode != 200) {
    throw AuthApiException(
      apiErrorMessage(response),
      statusCode: response.statusCode,
    );
  }
  return AuthUser.fromJson(_decodeBody(response));
}

Future<void> revokeRemoteSession({required String idToken}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/logout'),
    headers: _bearerHeaders(idToken),
  );
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw AuthApiException(apiErrorMessage(response));
  }
}

Future<UserProfile> fetchMe({required String accessToken}) async {
  final response = await http.get(
    Uri.parse('$apiBaseUrl/api/v1/users/me'),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (response.statusCode != 200) {
    throw AuthApiException(apiErrorMessage(response));
  }
  return UserProfile.fromJson(_decodeBody(response));
}

class AuthApiException implements Exception {
  final String message;

  /// Status HTTP de Nest cuando el error viene de la API (null si es local).
  final int? statusCode;

  const AuthApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Motivo de fallo de `/auth/session` o `/auth/register` relevante para el
/// flujo del cliente.
enum AuthApiFailure {
  /// 401 de session: el UID de Firebase no tiene User en Postgres.
  notSynced,

  /// 401 por token invalido/expirado u otra causa de sesion.
  invalidSession,

  /// 409: el correo pertenece a otra cuenta.
  emailTaken,

  /// 409 de register: el username ya existe.
  usernameTaken,

  /// 409 de register: el UID de Firebase ya tiene User.
  firebaseAccountTaken,

  other,
}

/// Unico punto que clasifica errores de la API de auth.
///
/// Decide por status HTTP (401 / 409). El texto solo desambigua dentro del
/// mismo status, porque Nest usa 401 tanto para "no sincronizado" como para
/// token invalido, y 409 para correo, username o UID duplicados
/// (ver `fit_track_api/src/auth/auth.service.ts`).
AuthApiFailure classifyAuthApiFailure(AuthApiException error) {
  final message = error.message.toLowerCase();
  switch (error.statusCode) {
    case 401:
      return message.contains('no sincronizado')
          ? AuthApiFailure.notSynced
          : AuthApiFailure.invalidSession;
    case 409:
      if (message.contains('usuario ya esta registrado')) {
        return AuthApiFailure.usernameTaken;
      }
      if (message.contains('firebase')) {
        return AuthApiFailure.firebaseAccountTaken;
      }
      return AuthApiFailure.emailTaken;
    default:
      return AuthApiFailure.other;
  }
}
