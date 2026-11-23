import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  /// Multipart `file` (+ campos opcionales, p. ej. `metricId` / `mealId` en fotos).
  Future<http.Response> uploadFile(
    String path,
    File file, {
    Map<String, String>? fields,
  }) async {
    final accessToken = await _storage.readAccessToken();
    var response = await _upload(path, file, accessToken, fields: fields);
    if (response.statusCode != 401) return response;

    final refreshed = await _tryRefresh();
    if (!refreshed) {
      await _storage.clear();
      notifySessionCleared();
      throw const SessionExpiredException();
    }

    final renewedToken = await _storage.readAccessToken();
    response = await _upload(path, file, renewedToken, fields: fields);
    if (response.statusCode == 401) {
      await _storage.clear();
      notifySessionCleared();
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
      notifySessionCleared();
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
      notifySessionCleared();
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
    if (method == 'DELETE') {
      return _http.delete(uri, headers: headers);
    }
    if (method == 'PATCH') {
      return _http.patch(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
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
    String? accessToken, {
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBaseUrl$path'),
    );
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: await uploadContentType(file),
      ),
    );
    final streamed = await _http.send(request);
    return http.Response.fromStream(streamed);
  }

  /// Content type de la parte `file`. `POST /photos` rechaza (400) si no
  /// coincide con el formato real (jpeg/png/webp), así que se detecta por
  /// firma de bytes y, si no hay firma conocida, por extensión.
  @visibleForTesting
  static Future<MediaType> uploadContentType(File file) async {
    final head = await _readHead(file, 12);
    final bySignature = _imageMimeFromSignature(head);
    final mime = bySignature ?? _imageMimeFromExtension(file.path);
    if (mime == null) return MediaType('application', 'octet-stream');
    return MediaType.parse(mime);
  }

  static Future<List<int>> _readHead(File file, int length) async {
    final bytes = <int>[];
    await for (final chunk in file.openRead(0, length)) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  static String? _imageMimeFromSignature(List<int> b) {
    bool startsWith(List<int> sig, [int offset = 0]) {
      if (b.length < offset + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (b[offset + i] != sig[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return 'image/webp';
    }
    return null;
  }

  static String? _imageMimeFromExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    switch (path.substring(dot + 1).toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
    }
    return null;
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
