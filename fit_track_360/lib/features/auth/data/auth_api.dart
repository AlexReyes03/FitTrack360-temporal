import 'dart:convert';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Tokens devueltos por el API en register y login.
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

/// Normaliza el mensaje de error del API: une listas de class-validator con
/// espacio, o devuelve un mensaje de red generico si no hay JSON.
String _errorMessage(http.Response response) {
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
    throw AuthApiException(_errorMessage(response));
  }
  return AuthTokens.fromJson(
    jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
  );
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
    throw AuthApiException(_errorMessage(response));
  }
  return AuthTokens.fromJson(
    jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
  );
}

class AuthApiException implements Exception {
  final String message;

  const AuthApiException(this.message);

  @override
  String toString() => message;
}
