import 'dart:convert';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Tokens devueltos por el API en register, login y refresh.
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int,
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

/// Normaliza el mensaje de error del API: une listas de class-validator con
/// espacio, o devuelve un mensaje de red generico si no hay JSON.
String apiErrorMessage(http.Response response) {
  try {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final message = body is Map<String, dynamic> ? body['message'] : null;
    if (message is List) return message.join(' ');
    if (message is String) return message;
  } catch (_) {
    // Sin JSON util: cae al mensaje por defecto.
  }
  return 'No se pudo conectar';
}

Map<String, dynamic> _decodeBody(http.Response response) =>
    jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

Future<AuthTokens> register({
  required String username,
  required String email,
  required String password,
  required String displayName,
  required bool privacyConsent,
  required String privacyNoticeVersion,
}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/register'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({
      'username': username,
      'email': email,
      'password': password,
      'displayName': displayName,
      'privacyConsent': privacyConsent,
      'privacyNoticeVersion': privacyNoticeVersion,
    }),
  );
  if (response.statusCode != 201) {
    throw AuthApiException(apiErrorMessage(response));
  }
  return AuthTokens.fromJson(_decodeBody(response));
}

Future<AuthTokens> login({
  required String email,
  required String password,
}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/login'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  if (response.statusCode != 200) {
    throw AuthApiException(apiErrorMessage(response));
  }
  return AuthTokens.fromJson(_decodeBody(response));
}

Future<AuthTokens> refreshTokens({required String refreshToken}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/refresh'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'refreshToken': refreshToken}),
  );
  if (response.statusCode != 200) {
    throw AuthApiException(apiErrorMessage(response));
  }
  return AuthTokens.fromJson(_decodeBody(response));
}

Future<void> logout({required String refreshToken}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/logout'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'refreshToken': refreshToken}),
  );
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw AuthApiException(apiErrorMessage(response));
  }
}

Future<void> forgotPassword({required String email}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/password/forgot'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email}),
  );
  if (response.statusCode != 200) {
    throw AuthApiException(apiErrorMessage(response));
  }
}

Future<void> resetPassword({
  required String code,
  required String password,
}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/v1/auth/password/reset'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'code': code, 'password': password}),
  );
  if (response.statusCode != 200) {
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

  const AuthApiException(this.message);

  @override
  String toString() => message;
}
