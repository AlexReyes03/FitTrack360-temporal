/// Tipos de aviso que la app muestra en el centro de notificaciones.
enum AppNotificationType { newLogin, passwordChanged, reminder }

/// Etiqueta legible para filtros y listas.
extension AppNotificationTypeLabel on AppNotificationType {
  String get label => switch (this) {
    AppNotificationType.newLogin => 'Inicio de sesión',
    AppNotificationType.passwordChanged => 'Contraseña',
    AppNotificationType.reminder => 'Recordatorio',
  };
}

/// Valor canónico del tipo en la API (query `type`).
extension AppNotificationTypeApi on AppNotificationType {
  String get apiValue => switch (this) {
    AppNotificationType.newLogin => 'new_login',
    AppNotificationType.passwordChanged => 'password_changed',
    AppNotificationType.reminder => 'reminder',
  };
}

/// Aviso mostrado al usuario. Inmutable: los cambios de lectura se hacen con
/// [copyWith] para que la lista del ViewModel siempre sea consistente.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.targetRoute,
  });

  final String id;
  final String title;
  final String message;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;

  /// Momento en que se marcó como leída; null si sigue pendiente.
  final DateTime? readAt;

  /// Ruta interna a la que navega la notificación (deep-link in-app).
  final String? targetRoute;

  /// Alias usado por algunos consumidores que hablan de "body".
  String get body => message;

  /// Parser tolerante para las respuestas de NestJS.
  ///
  /// Acepta `body` o `message`, tipos en snake_case, camelCase o mayúsculas,
  /// y `targetRoute` o `deeplink`. Un tipo desconocido cae en recordatorio.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: _asText(json['title']),
      message: _asText(json['body'] ?? json['message']),
      type: _parseType(json['type']),
      createdAt:
          _parseDate(json['createdAt'] ?? json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isRead: json['isRead'] == true || json['is_read'] == true,
      readAt: _parseDate(json['readAt'] ?? json['read_at']),
      targetRoute: _asNullableText(
        json['targetRoute'] ?? json['target_route'] ?? json['deeplink'],
      ),
    );
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    AppNotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    bool clearReadAt = false,
    String? targetRoute,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      targetRoute: targetRoute ?? this.targetRoute,
    );
  }

  static AppNotificationType _parseType(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return switch (normalized) {
      'newlogin' || 'login' || 'security' => AppNotificationType.newLogin,
      'passwordchanged' ||
      'passwordchange' => AppNotificationType.passwordChanged,
      'reminder' ||
      'dailyreminder' ||
      'trainingreminder' => AppNotificationType.reminder,
      _ => AppNotificationType.reminder,
    };
  }

  static String _asText(Object? value) =>
      value is String ? value : (value?.toString() ?? '');

  static String? _asNullableText(Object? value) {
    final text = _asText(value).trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
