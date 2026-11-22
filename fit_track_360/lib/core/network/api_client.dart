import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_api.dart';
import '../session_storage.dart';

/// La sesion ya no se puede renovar: el refresh del ID token fallo.
class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'Sesion expirada';
}

/// Cliente HTTP con Bearer (ID token Firebase). Ante 401 fuerza un refresh
/// del ID token y reintenta una vez.
class ApiClient {
  final SessionStorage _storage;
  final http.Client _http;

  ApiClient({SessionStorage? storage, http.Client? httpClient})
    : _storage = storage ?? appSessionStorage,
      _http = httpClient ?? http.Client();

  Future<UserProfile> me() async {
    final response = await get('/api/v1/users/me');
    if (response.statusCode != 200) {
      throw AuthApiException(apiErrorMessage(response));
    }
    return UserProfile.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<http.Response> get(String path) => _send('GET', path);

  Future<http.Response> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<http.Response> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<http.Response> delete(String path) => _send('DELETE', path);

  Future<http.Response> uploadFile(String path, File file) async {
    final accessToken = await _storage.readAccessToken();
    var response = await _upload(path, file, accessToken);
    if (response.statusCode != 401) return response;

    final refreshed = await _tryRefresh();
    if (!refreshed) {
      await _storage.clear();
      throw const SessionExpiredException();
    }

    final renewedToken = await _storage.readAccessToken();
    response = await _upload(path, file, renewedToken);
    if (response.statusCode == 401) {
      await _storage.clear();
      throw const SessionExpiredException();
    }
    return response;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    final accessToken = await _storage.readAccessToken();
    var response = await _request(
      method,
      path,
      body: body,
      accessToken: accessToken,
    );
    if (response.statusCode != 401) return response;

    final refreshed = await _tryRefresh();
    if (!refreshed) {
      await _storage.clear();
      throw const SessionExpiredException();
    }

    final renewedToken = await _storage.readAccessToken();
    response = await _request(
      method,
      path,
      body: body,
      accessToken: renewedToken,
    );
    if (response.statusCode == 401) {
      await _storage.clear();
      throw const SessionExpiredException();
    }
    return response;
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
    String? accessToken,
  }) {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    if (method == 'GET') {
      return _http.get(uri, headers: headers);
    }
    if (method == 'PATCH') {
      return _http.patch(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    }
    if (method == 'DELETE') {
      return _http.delete(uri, headers: headers);
    }
    return _http.post(
      uri,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> _upload(
    String path,
    File file,
    String? accessToken,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBaseUrl$path'),
    );
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await _http.send(request);
    return http.Response.fromStream(streamed);
  }

  Future<bool> _tryRefresh() async {
    try {
      final renewed = await _storage.readAccessToken(forceRefresh: true);
      return renewed != null && renewed.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _http.close();
  }
}
