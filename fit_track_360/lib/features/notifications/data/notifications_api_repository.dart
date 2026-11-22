import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api.dart';
import '../domain/app_notification.dart';
import '../domain/notifications_repository.dart';

/// La notificación no existe o pertenece a otro usuario (regla S4: 404).
class NotificationNotFoundException implements Exception {
  const NotificationNotFoundException();

  @override
  String toString() => 'Notificación no encontrada';
}

/// Error del API de notificaciones con el status HTTP cuando aplica.
class NotificationsApiException implements Exception {
  const NotificationsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente de `/api/v1/notifications` sobre [ApiClient].
///
/// El Bearer y el refresh de sesión los resuelve [ApiClient]. Un 404 en una
/// operación individual se traduce a [NotificationNotFoundException] para no
/// filtrar si el recurso existe o es de otro usuario.
class NotificationsApiRepository implements NotificationsRepository {
  NotificationsApiRepository(this._client);

  final ApiClient _client;

  static const _base = '/api/v1/notifications';

  @override
  Future<List<AppNotification>> fetchNotifications({
    bool? isRead,
    AppNotificationType? type,
  }) async {
    final query = <String, String>{
      if (isRead != null) 'isRead': isRead.toString(),
      if (type != null) 'type': type.apiValue,
    };
    final path = query.isEmpty
        ? _base
        : '$_base?${Uri(queryParameters: query).query}';
    final response = await _client.get(path);
    if (response.statusCode != 200) throw _error(response);

    final body = _decodeOrNull(response);
    final raw = switch (body) {
      List<dynamic>() => body,
      Map<String, dynamic>() => body['items'] ?? body['data'],
      _ => null,
    };
    if (raw is! List) {
      throw NotificationsApiException(
        'No se pudo conectar',
        statusCode: response.statusCode,
      );
    }

    final notifications = <AppNotification>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        notifications.add(AppNotification.fromJson(item));
      }
    }
    return notifications;
  }

  @override
  Future<int> fetchUnreadCount() async {
    final response = await _client.get('$_base/unread-count');
    if (response.statusCode != 200) throw _error(response);

    final body = _decodeOrNull(response);
    final value = switch (body) {
      Map<String, dynamic>() => body['unreadCount'] ?? body['count'],
      _ => body,
    };
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Future<AppNotification?> updateRead(String id, {required bool isRead}) async {
    final response = await _client.patch(
      '$_base/${Uri.encodeComponent(id)}/read',
      body: {'isRead': isRead},
    );
    if (response.statusCode == 404) {
      throw const NotificationNotFoundException();
    }
    if (!_isSuccess(response.statusCode)) throw _error(response);

    final body = _decodeOrNull(response);
    if (body is Map<String, dynamic>) {
      final nested = body['notification'];
      final map = nested is Map<String, dynamic> ? nested : body;
      if (map.containsKey('id')) return AppNotification.fromJson(map);
    }
    return null;
  }

  @override
  Future<void> markAllAsRead() async {
    final response = await _client.patch('$_base/read-all');
    if (!_isSuccess(response.statusCode)) throw _error(response);
  }

  @override
  Future<void> deleteNotification(String id) async {
    final response = await _client.delete('$_base/${Uri.encodeComponent(id)}');
    if (response.statusCode == 404) {
      throw const NotificationNotFoundException();
    }
    if (!_isSuccess(response.statusCode)) throw _error(response);
  }

  @override
  Future<void> deleteAll() async {
    final response = await _client.delete(_base);
    if (!_isSuccess(response.statusCode)) throw _error(response);
  }

  static bool _isSuccess(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  static Object? _decodeOrNull(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  static NotificationsApiException _error(http.Response response) =>
      NotificationsApiException(
        apiErrorMessage(response),
        statusCode: response.statusCode,
      );
}
