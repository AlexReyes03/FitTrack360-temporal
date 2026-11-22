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
  });

  final String id;
  final String title;
  final String message;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;

  /// Alias usado por algunos consumidores que hablan de "body".
  String get body => message;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
